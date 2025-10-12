import os
import shutil
from typing import List, Tuple, Optional
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from urllib.parse import urlparse
from PIL import Image
import uuid
from app.config import settings


class DirectoryService:
    def __init__(self):
        self.s3_client = None
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
            else:
                print("AWS credentials not found. S3 functionality will be limited.")
        except Exception as e:
            print(f"Failed to initialize S3 client: {e}")

    def is_s3_path(self, path: str) -> bool:
        """Check if path is an S3 URL"""
        return (
            path.startswith("s3://") or path.startswith("https://s3.") or ".s3." in path
        )

    def parse_s3_path(self, s3_path: str) -> Tuple[str, str]:
        """Parse S3 path to extract bucket and prefix"""
        if s3_path.startswith("s3://"):
            # s3://bucket/path/to/folder
            parts = s3_path[5:].split("/", 1)
            bucket = parts[0]
            prefix = parts[1] if len(parts) > 1 else ""
        elif "amazonaws.com" in s3_path:
            # https://bucket.s3.region.amazonaws.com/path/to/folder
            parsed = urlparse(s3_path)
            bucket = parsed.netloc.split(".")[0]
            prefix = parsed.path.lstrip("/")
        else:
            raise ValueError(f"Invalid S3 path format: {s3_path}")

        return bucket, prefix

    def get_image_files_from_local(self, file_path: str) -> List[str]:
        """Get single image file from local path"""
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")

        if not self._is_image_file(file_path):
            raise ValueError(f"Not an image file: {file_path}")

        return [file_path]

    def get_image_files_from_s3(self, s3_path: str) -> List[str]:
        """Get single image file from S3 path"""
        if not self.s3_client:
            raise Exception("S3 client not initialized. Check AWS credentials.")

        bucket, key = self.parse_s3_path(s3_path)

        try:
            # Verify the object exists
            self.s3_client.head_object(Bucket=bucket, Key=key)

            if not self._is_image_file(key):
                raise ValueError(f"Not an image file: {s3_path}")

            return [f"s3://{bucket}/{key}"]

        except ClientError as e:
            raise Exception(f"Error accessing S3: {e}")

    def download_from_s3(self, s3_path: str, local_filename: str) -> str:
        """Download file from S3 to local uploads directory"""
        if not self.s3_client:
            raise Exception("S3 client not initialized. Check AWS credentials.")

        bucket, key = self.parse_s3_path(s3_path)
        local_path = os.path.join(settings.UPLOAD_DIR, local_filename)

        try:
            self.s3_client.download_file(bucket, key, local_path)
            return local_path
        except ClientError as e:
            raise Exception(f"Error downloading from S3: {e}")

    def copy_from_local(self, source_path: str, local_filename: str) -> str:
        """Copy file from local source to uploads directory"""
        if not os.path.exists(source_path):
            raise FileNotFoundError(f"Source file not found: {source_path}")

        local_path = os.path.join(settings.UPLOAD_DIR, local_filename)
        shutil.copy2(source_path, local_path)
        return local_path

    def process_directory(self, image_path: str) -> List[Tuple[str, str]]:
        """
        Process a single image (local or S3) and copy/download it to uploads/images
        Returns list with one tuple (original_path, local_path)
        """
        try:
            # Generate unique filename
            original_filename = os.path.basename(image_path)
            name, ext = os.path.splitext(original_filename)
            unique_filename = f"{name}_{uuid.uuid4().hex[:8]}{ext}"

            if self.is_s3_path(image_path):
                # Get and verify S3 image
                image_files = self.get_image_files_from_s3(image_path)
                if not image_files:
                    return []

                s3_file_path = image_files[0]
                local_path = self.download_from_s3(s3_file_path, unique_filename)
                return [(s3_file_path, local_path)]

            else:
                # Get and verify local image
                image_files = self.get_image_files_from_local(image_path)
                if not image_files:
                    return []

                local_file_path = image_files[0]
                copied_path = self.copy_from_local(local_file_path, unique_filename)
                return [(local_file_path, copied_path)]

        except (FileNotFoundError, ValueError) as e:
            print(f"Error processing image: {e}")
            return []
        except Exception as e:
            print(f"Unexpected error processing image: {e}")
            return []

    def _is_image_file(self, file_path: str) -> bool:
        """Check if file is a valid image based on extension"""
        _, ext = os.path.splitext(file_path.lower())
        return ext in settings.ALLOWED_EXTENSIONS

    def validate_image(self, file_path: str) -> bool:
        """Validate that the file is actually a valid image"""
        try:
            with Image.open(file_path) as img:
                img.verify()
            return True
        except Exception:
            return False
