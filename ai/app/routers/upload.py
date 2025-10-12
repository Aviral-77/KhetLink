from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.database import get_db, generate_id
from app.models import Image, Farmer
from app.schemas import UploadPhotoResponse, UploadRemoteImageRequest
from app.services.directory_service import DirectoryService
from app.config import settings
from datetime import datetime
import os
import shutil
from typing import Optional, List

router = APIRouter()

UPLOAD_DIR = settings.UPLOAD_DIR
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/upload-photo", response_model=UploadPhotoResponse)
async def upload_photo(
    file: UploadFile = File(...),
    farmer_id: str = Form(...),
    crop: str = Form(...),
    lat: Optional[float] = Form(None),
    lon: Optional[float] = Form(None),
    capture_ts: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    image_id = f"img_{generate_id()}"

    file_extension = os.path.splitext(file.filename)[1]
    file_path = os.path.join(UPLOAD_DIR, f"{image_id}{file_extension}")

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    capture_timestamp = None
    if capture_ts:
        try:
            capture_timestamp = datetime.fromisoformat(
                capture_ts.replace("Z", "+00:00")
            )
        except:
            capture_timestamp = None

    farmer = db.query(Farmer).filter(Farmer.farmer_id == farmer_id).first()
    if not farmer:
        farmer = Farmer(farmer_id=farmer_id)
        db.add(farmer)

    db_image = Image(
        image_id=image_id,
        farmer_id=farmer_id,
        crop=crop,
        file_path=file_path,
        latitude=lat,
        longitude=lon,
        capture_ts=capture_timestamp,
        upload_ts=datetime.utcnow(),
    )

    db.add(db_image)
    db.commit()
    db.refresh(db_image)

    return UploadPhotoResponse(image_id=image_id, upload_ts=db_image.upload_ts)


@router.post("/upload-remote", response_model=UploadPhotoResponse)
async def upload_remote_image(
    request: UploadRemoteImageRequest, db: Session = Depends(get_db)
):
    """
    Upload a single image from an S3 URL to the application.

    Example:
    - S3 HTTPS: "https://bucket-name.s3.amazonaws.com/folder/image.jpg"
    """
    directory_service = DirectoryService()

    try:
        # Process the single image and get its local path
        processed_files = directory_service.process_directory(request.image_path)

        if not processed_files or len(processed_files) != 1:
            raise HTTPException(
                status_code=404,
                detail=f"Image not found or invalid path: {request.image_path}",
            )

        original_path, local_path = processed_files[0]

        # Validate the downloaded image
        if not directory_service.validate_image(local_path):
            if os.path.exists(local_path):
                os.remove(local_path)
            raise HTTPException(status_code=400, detail="Invalid image file")

        # Ensure farmer exists
        farmer = db.query(Farmer).filter(Farmer.farmer_id == request.farmer_id).first()
        if not farmer:
            farmer = Farmer(farmer_id=request.farmer_id)
            db.add(farmer)
            db.commit()

        # Generate image ID
        image_id = f"img_{generate_id()}"

        # Create database entry
        db_image = Image(
            image_id=image_id,
            farmer_id=request.farmer_id,
            crop=request.crop,
            file_path=local_path,
            latitude=request.lat,
            longitude=request.lon,
            capture_ts=request.capture_ts,
            upload_ts=datetime.utcnow(),
        )

        db.add(db_image)
        db.commit()
        db.refresh(db_image)

        return UploadPhotoResponse(image_id=image_id, upload_ts=db_image.upload_ts)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")
