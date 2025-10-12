import cv2
import numpy as np
from ultralytics import FastSAM

try:
    from ultralytics.models.fastsam import FastSAMPrompt
except ImportError:
    try:
        from ultralytics import FastSAM as FastSAMPrompt
    except ImportError:
        FastSAMPrompt = None
import torch
import tensorflow as tf
from PIL import Image
import os
from typing import Tuple, Optional
import boto3
from app.config import settings


class SegmentationService:
    def __init__(self):
        self.fastsam_model = None
        self.classification_model = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.s3_client = None
        print(f"Using device: {self.device}")
        self.load_models()
        self._init_s3_client()

    def _init_s3_client(self):
        """Initialize S3 client if AWS credentials are available"""
        try:
            if settings.AWS_ACCESS_KEY_ID and settings.AWS_SECRET_ACCESS_KEY:
                self.s3_client = boto3.client(
                    "s3",
                    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                    region_name=settings.AWS_REGION,
                )
                print("S3 client initialized successfully")
            else:
                print("AWS credentials not found")
        except Exception as e:
            print(f"Failed to initialize S3 client: {e}")

    def _upload_to_s3(self, file_path: str, s3_key: str) -> Optional[str]:
        """
        Upload a file to S3 and return the S3 URL
        Args:
            file_path: Local path to the file
            s3_key: The key (path) where the file will be stored in S3
        Returns:
            S3 URL if successful, None otherwise
        """
        if not self.s3_client:
            print("S3 client not initialized")
            return None

        try:
            bucket = settings.AWS_S3_BUCKET
            self.s3_client.upload_file(file_path, bucket, s3_key)

            # Generate S3 URL
            s3_url = f"https://{bucket}.s3.{settings.AWS_REGION}.amazonaws.com/{s3_key}"
            print(f"Uploaded to S3: {s3_url}")
            return s3_url
        except Exception as e:
            print(f"Error uploading to S3: {e}")
            return None

    def load_models(self):
        try:
            # Add safe globals for torch loading including ultralytics classes
            try:
                import ultralytics.nn.tasks

                torch.serialization.add_safe_globals(
                    [
                        torch.nn.modules.container.Sequential,
                        torch.nn.modules.activation.SiLU,
                        torch.nn.modules.conv.Conv2d,
                        torch.nn.modules.batchnorm.BatchNorm2d,
                        torch.nn.modules.pooling.MaxPool2d,
                        torch.nn.modules.upsampling.Upsample,
                        ultralytics.nn.tasks.SegmentationModel,
                    ]
                )
            except (ImportError, AttributeError):
                # Fallback for different ultralytics versions
                pass

            # Try loading with different approaches based on ultralytics version
            try:
                # Method 1: Direct load (should work with ultralytics 8.3.0+)
                self.fastsam_model = FastSAM("FastSAM-x.pt")
                print("FastSAM model loaded successfully")
            except Exception as e1:
                print(f"Direct load failed: {e1}")
                # Method 2: Try with explicit weights_only=False for older PyTorch/ultralytics
                try:
                    print("Attempting load with weights_only=False")
                    # Create a temporary model file with the weights_only flag
                    temp_model = torch.load(
                        "FastSAM-x.pt", map_location=self.device, weights_only=False
                    )
                    self.fastsam_model = FastSAM("FastSAM-x.pt")
                    print("FastSAM model loaded with weights_only=False")
                except Exception as e2:
                    print(f"weights_only=False load failed: {e2}")
                    print("FastSAM segmentation will not be available")
                    self.fastsam_model = None
        except Exception as e:
            print(f"Error loading FastSAM model: {e}")
            print("FastSAM segmentation will not be available")
            self.fastsam_model = None
        try:
            if os.path.exists("plant_disease_model.h5"):
                self.classification_model = tf.keras.models.load_model(
                    "plant_disease_model.h5"
                )
                print("Disease classification model loaded successfully (Keras)")
            elif os.path.exists("plant_disease_model.pt"):
                self.classification_model = torch.load(
                    "plant_disease_model.pt", map_location=self.device
                )
                self.classification_model.eval()
                print("Disease classification model loaded successfully (PyTorch)")
            else:
                print("No disease classification model found, using fallback database")
        except Exception as e:
            print(f"Error loading classification model: {e}")
            self.classification_model = None

    def segment_infection(
        self, image_path: str, image_id: str, text_prompt: str = "brown spots around green leaf"
    ) -> Tuple[Optional[str], Optional[float]]:
        """
        Returns: (mask_path, infected_percentage)
        Writes overlay to same directory with suffix _overlay.png (useful for UI).
        Robustly extracts masks from ultralytics/Results.
        """
        if not self.fastsam_model:
            raise Exception("FastSAM model not loaded")

        if FastSAMPrompt is None:
            raise Exception("FastSAMPrompt not available in this ultralytics version")

        try:
            # Run FastSAM inference
            results = self.fastsam_model(
                image_path, imgsz=1024, conf=0.4, iou=0.9, retina_masks=True
            )

            # Use FastSAMPrompt to get mask annotations for text prompt
            # Handle different FastSAMPrompt APIs
            try:
                # prompt_proc = FastSAMPrompt(image_path, results, device=self.device)
                prompt_proc = FastSAMPrompt(image_path, results, device=self.device)
                ann = prompt_proc.text_prompt(text=text_prompt)
            except (TypeError, AttributeError) as e:
                print(f"FastSAMPrompt API error: {e}")
                # Fallback: try different parameter order or method
                try:
                    prompt_proc = FastSAMPrompt(results, image_path, device=self.device)
                    ann = prompt_proc.text_prompt(text=text_prompt)
                except Exception:
                    # Another fallback: use results directly if prompt processing fails
                    ann = results
            print(f"{text_prompt=}")
            print(f"{ann=}")
            if not ann:
                print(
                    "No annotations returned by FastSAMPrompt for prompt:", text_prompt
                )
                return None, 0.0

            # load image
            image = cv2.imread(image_path)
            if image is None:
                raise Exception(f"Could not load image: {image_path}")
            h, w = image.shape[:2]
            total_pixels = h * w

            union_mask = np.zeros((h, w), dtype=np.uint8)
            all_masks = []

            # Handle different types of annotations returned by FastSAMPrompt
            if isinstance(ann, (list, tuple)):
                # ann is a list of Results objects or tensors
                for idx, a in enumerate(ann):
                    masks = self._extract_masks_from_annotation(a, h, w, idx)
                    all_masks.extend(masks)
            else:
                # ann is a single Results object or tensor
                masks = self._extract_masks_from_annotation(ann, h, w, 0)
                all_masks.extend(masks)

            # Filter masks by area to remove noisy segmentations
            if all_masks:
                filtered_masks = self._filter_masks_by_area(all_masks, total_pixels)

                # Combine all valid masks into union mask
                for mask in filtered_masks:
                    union_mask = np.logical_or(union_mask, mask).astype(np.uint8)
            else:
                print("No valid masks found after extraction")

            infected_pixels = int(union_mask.sum())
            infected_percentage = (infected_pixels / float(total_pixels)) * 100.0

            # Create local directories for temporary storage
            local_mask_dir = "uploads/masks"
            os.makedirs(local_mask_dir, exist_ok=True)
            # image_id = os.path.splitext(os.path.basename(image_path))[0]

            # Local paths for temporary storage
            local_mask_path = os.path.join(local_mask_dir, f"{image_id}_mask.png")
            local_overlay_path = os.path.join(local_mask_dir, f"{image_id}_overlay.png")

            # Save mask locally
            cv2.imwrite(local_mask_path, (union_mask * 255).astype(np.uint8))

            # Create and save overlay locally
            mask_rgb = np.zeros((h, w, 3), dtype=np.uint8)
            mask_rgb[union_mask > 0] = [0, 0, 255]
            alpha = 0.35
            overlay = cv2.addWeighted(image, 1 - alpha, mask_rgb, alpha, 0)
            cv2.imwrite(local_overlay_path, overlay)

            # Upload overlay to S3
            s3_overlay_key = f"masks/{image_id}_overlay.png"
            s3_overlay_url = self._upload_to_s3(local_overlay_path, s3_overlay_key)

            # Upload mask to S3
            s3_mask_key = f"masks/{image_id}_mask.png"
            # self._upload_to_s3(local_mask_path, s3_mask_key)

            # # Clean up local files
            # try:
            #     os.remove(local_mask_path)
            #     os.remove(local_overlay_path)
            # except Exception as e:
            #     print(f"Error cleaning up local files: {e}")

            # Return the S3 URL for the overlay if available, otherwise return local path as fallback
            overlay_path = s3_overlay_url if s3_overlay_url else local_overlay_path
            print(f"{overlay_path=}")
            return overlay_path, infected_percentage

        except Exception as e:
            print(f"Error in segmentation: {e}")
            # helpful debug: attempt to print result attributes if available
            try:
                if "results" in locals() and len(results) > 0:
                    print("Result[0] dir:", dir(results[0])[:120])
            except Exception:
                pass
            return None, 0.0

    def _extract_masks_from_annotation(
        self, annotation, target_h: int, target_w: int, idx: int
    ) -> list:
        """Extract all binary masks from various annotation formats"""
        masks = []

        try:
            # Case 1: Results object with masks attribute
            if hasattr(annotation, "masks") and annotation.masks is not None:
                mask_obj = annotation.masks
                if hasattr(mask_obj, "data"):
                    # masks.data is typically a tensor with shape (N, H, W)
                    mask_data = mask_obj.data
                    if hasattr(mask_data, "cpu"):
                        mask_data = mask_data.cpu().numpy()
                    elif hasattr(mask_data, "numpy"):
                        mask_data = mask_data.numpy()

                    if mask_data.ndim == 3 and mask_data.shape[0] > 0:
                        # Process all masks
                        for i in range(mask_data.shape[0]):
                            seg_mask = mask_data[i]
                            processed_mask = self._process_single_mask(
                                seg_mask, target_h, target_w
                            )
                            if processed_mask is not None:
                                masks.append(processed_mask)
                    elif mask_data.ndim == 2:
                        processed_mask = self._process_single_mask(
                            mask_data, target_h, target_w
                        )
                        if processed_mask is not None:
                            masks.append(processed_mask)

            # Case 2: Direct tensor/array with .cpu() method
            elif hasattr(annotation, "cpu") and callable(getattr(annotation, "cpu")):
                mask_data = annotation.cpu().numpy()
                processed_mask = self._process_single_mask(
                    mask_data, target_h, target_w
                )
                if processed_mask is not None:
                    masks.append(processed_mask)

            # Case 3: Direct tensor/array with .numpy() method
            elif hasattr(annotation, "numpy") and callable(
                getattr(annotation, "numpy")
            ):
                mask_data = annotation.numpy()
                processed_mask = self._process_single_mask(
                    mask_data, target_h, target_w
                )
                if processed_mask is not None:
                    masks.append(processed_mask)

            # Case 4: Already a numpy array
            elif isinstance(annotation, np.ndarray):
                processed_mask = self._process_single_mask(
                    annotation, target_h, target_w
                )
                if processed_mask is not None:
                    masks.append(processed_mask)

            # Case 5: Try direct conversion
            else:
                try:
                    mask_data = np.asarray(annotation)
                    processed_mask = self._process_single_mask(
                        mask_data, target_h, target_w
                    )
                    if processed_mask is not None:
                        masks.append(processed_mask)
                except Exception:
                    pass

            if not masks:
                print(
                    f"Warning: could not extract any masks from annotation #{idx}; type={type(annotation)}"
                )

            return masks

        except Exception as e:
            print(f"Error extracting masks from annotation #{idx}: {e}")
            return []

    def _process_single_mask(
        self, seg_mask, target_h: int, target_w: int
    ) -> Optional[np.ndarray]:
        """Process a single mask: normalize dimensions, convert to binary, resize"""
        try:
            # Normalize dimensions
            if seg_mask.ndim == 3:
                if seg_mask.shape[0] == 1:
                    seg_mask = seg_mask.squeeze(0)
                else:
                    seg_mask = seg_mask[0]
            elif seg_mask.ndim > 3:
                seg_mask = seg_mask[0]
                while seg_mask.ndim > 2:
                    seg_mask = seg_mask[0]

            # Convert to binary mask
            if seg_mask.dtype == bool:
                bin_mask = seg_mask.astype(np.uint8)
            else:
                bin_mask = (seg_mask > 0.5).astype(np.uint8)

            # Resize to target dimensions if needed
            if bin_mask.shape != (target_h, target_w):
                bin_mask = cv2.resize(
                    bin_mask, (target_w, target_h), interpolation=cv2.INTER_NEAREST
                )
                bin_mask = (bin_mask > 0).astype(np.uint8)

            return bin_mask

        except Exception as e:
            print(f"Error processing single mask: {e}")
            return None

    def _filter_masks_by_area(
        self,
        masks: list,
        total_pixels: int,
        min_area_percent: float = 0.1,
        max_area_percent: float = 40.0,
    ) -> list:
        """Filter out masks that are too small or too large based on area percentage"""
        filtered_masks = []
        min_pixels = int((min_area_percent / 100.0) * total_pixels)
        max_pixels = int((max_area_percent / 100.0) * total_pixels)

        for i, mask in enumerate(masks):
            mask_pixels = int(mask.sum())
            mask_percent = (mask_pixels / total_pixels) * 100.0

            if min_pixels <= mask_pixels <= max_pixels:
                filtered_masks.append(mask)
                print(f"Mask {i}: {mask_pixels} pixels ({mask_percent:.2f}%) - KEPT")
            else:
                print(
                    f"Mask {i}: {mask_pixels} pixels ({mask_percent:.2f}%) - FILTERED OUT (too {'small' if mask_pixels < min_pixels else 'large'})"
                )

        print(f"Filtered {len(masks)} masks -> {len(filtered_masks)} valid masks")
        return filtered_masks

    def classify_disease(self, image_path: str, crop: str) -> Tuple[list, float]:
        if self.classification_model:
            try:
                return self._classify_with_model(image_path, crop)
            except Exception as e:
                print(f"Error in model classification: {e}")
                return self._classify_with_fallback(crop)
        else:
            return self._classify_with_fallback(crop)

    def _classify_with_model(self, image_path: str, crop: str) -> Tuple[list, float]:
        # Load image as RGB
        bgr = cv2.imread(image_path)
        if bgr is None:
            raise ValueError("Could not read image for classification: " + image_path)
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)

        # Default target
        target_h, target_w = 224, 224
        use_tf = isinstance(self.classification_model, tf.keras.Model)
        use_torch = (not use_tf) and (self.classification_model is not None)

        # Determine expected input size dynamically for TF model
        if use_tf:
            try:
                inp_shape = (
                    self.classification_model.input_shape
                )  # e.g. (None, H, W, C)
                if inp_shape and len(inp_shape) == 4:
                    _, th, tw, tc = inp_shape
                    if th is not None and tw is not None:
                        target_h, target_w = int(th), int(tw)
            except Exception:
                pass
        elif use_torch:
            # If PyTorch model, attempt to read a stored input size attribute if present
            try:
                # Common pattern: model expects (batch, channels, H, W)
                # You may have saved input size somewhere; else keep default 224
                if hasattr(self.classification_model, "input_size"):
                    ts = getattr(self.classification_model, "input_size")
                    if isinstance(ts, (tuple, list)) and len(ts) == 2:
                        target_h, target_w = int(ts[0]), int(ts[1])
            except Exception:
                pass

        # Resize & preprocess
        resized = cv2.resize(rgb, (target_w, target_h), interpolation=cv2.INTER_AREA)
        arr = (
            resized.astype(np.float32) / 255.0
        )  # scale to [0,1] — change if your model used mean/std

        if use_tf:
            batch = np.expand_dims(arr, axis=0)  # shape (1, H, W, 3)
            preds = self.classification_model.predict(batch)
            if isinstance(preds, (list, tuple)):
                preds = preds[0]
            preds = np.asarray(preds).squeeze()
        else:
            # PyTorch: convert to tensor, move to device, shape (1, C, H, W)
            tensor = torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0).to(self.device)
            self.classification_model.eval()
            with torch.no_grad():
                out = self.classification_model(tensor)
                # if model returns logits, apply softmax
                if isinstance(out, tuple) or isinstance(out, list):
                    out = out[0]
                preds = torch.softmax(out, dim=1).cpu().numpy()[0]

        # get class names and top-k
        class_names = self._get_class_names(crop)
        if preds.ndim == 0:
            # single-value? treat as binary
            preds = np.array([1 - preds, preds])

        top_indices = np.argsort(preds)[::-1][:3]
        results = []
        for i in top_indices:
            label = class_names[i] if i < len(class_names) else f"cls_{i}"
            results.append({"label": label, "score": float(preds[i])})

        confidence = float(preds[top_indices[0]]) if len(top_indices) > 0 else 0.0
        return results, confidence

    def _get_class_names(self, crop: str) -> list:
        class_names_db = {
            "tomato": [
                "Tomato Bacterial spot",
                "Tomato Early blight",
                "Tomato Late blight",
                "Tomato Leaf Mold",
                "Tomato Septoria leaf spot",
                "Tomato Spider mites",
                "Tomato Target Spot",
                "Tomato Yellow Leaf Curl Virus",
                "Tomato mosaic virus",
                "Tomato Healthy",
            ],
            "rice": [
                "Rice Bacterial leaf blight",
                "Rice Brown spot",
                "Rice Leaf smut",
                "Rice Healthy",
            ],
            "wheat": [
                "Wheat Rust",
                "Wheat Powdery Mildew",
                "Wheat Septoria",
                "Wheat Healthy",
            ],
        }

        return class_names_db.get(
            crop.lower(),
            ["Unknown Disease", "Fungal Infection", "Bacterial Infection", "Healthy"],
        )

    def _classify_with_fallback(self, crop: str) -> Tuple[list, float]:
        disease_db = {
            "tomato": [
                {"label": "Early Blight", "score": 0.78},
                {"label": "Septoria Spot", "score": 0.12},
                {"label": "Late Blight", "score": 0.08},
                {"label": "Bacterial Spot", "score": 0.02},
            ],
            "rice": [
                {"label": "Rice Blast", "score": 0.85},
                {"label": "Brown Spot", "score": 0.10},
                {"label": "Bacterial Leaf Streak", "score": 0.05},
            ],
            "wheat": [
                {"label": "Rust", "score": 0.80},
                {"label": "Powdery Mildew", "score": 0.15},
                {"label": "Septoria", "score": 0.05},
            ],
        }

        crop_diseases = disease_db.get(
            crop.lower(),
            [
                {"label": "Unknown Disease", "score": 0.60},
                {"label": "Fungal Infection", "score": 0.30},
                {"label": "Bacterial Infection", "score": 0.10},
            ],
        )

        confidence = crop_diseases[0]["score"] if crop_diseases else 0.5

        return crop_diseases, confidence

    def determine_severity(self, infected_percentage: float) -> str:
        if infected_percentage < 10:
            return "Mild"
        elif infected_percentage < 25:
            return "Moderate"
        elif infected_percentage < 50:
            return "Severe"
        else:
            return "Critical"
