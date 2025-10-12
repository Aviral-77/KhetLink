from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Image, Analysis
import os

router = APIRouter()

@router.get("/image/{image_id}")
async def get_image(image_id: str, db: Session = Depends(get_db)):
    image_record = db.query(Image).filter(Image.image_id == image_id).first()
    if not image_record:
        raise HTTPException(status_code=404, detail="Image not found")
    
    if not os.path.exists(image_record.file_path):
        raise HTTPException(status_code=404, detail="Image file not found")
    
    return FileResponse(
        path=image_record.file_path,
        media_type="image/jpeg",
        filename=f"{image_id}.jpg"
    )

@router.get("/mask/{image_id}")
async def get_mask(image_id: str, db: Session = Depends(get_db)):
    analysis = db.query(Analysis).filter(Analysis.image_id == image_id, Analysis.status == "done").first()
    if not analysis or not analysis.mask_path:
        raise HTTPException(status_code=404, detail="Mask not found")
    
    if not os.path.exists(analysis.mask_path):
        raise HTTPException(status_code=404, detail="Mask file not found")
    
    return FileResponse(
        path=analysis.mask_path,
        media_type="image/png",
        filename=f"{image_id}_mask.png"
    )

@router.get("/overlay/{image_id}")
async def get_overlay(image_id: str, db: Session = Depends(get_db)):
    analysis = db.query(Analysis).filter(Analysis.image_id == image_id, Analysis.status == "done").first()
    if not analysis or not analysis.mask_path:
        raise HTTPException(status_code=404, detail="Overlay not found")
    
    mask_dir = os.path.dirname(analysis.mask_path)
    overlay_path = os.path.join(mask_dir, f"{image_id}_overlay.png")
    
    if not os.path.exists(overlay_path):
        raise HTTPException(status_code=404, detail="Overlay file not found")
    
    return FileResponse(
        path=overlay_path,
        media_type="image/png",
        filename=f"{image_id}_overlay.png"
    )