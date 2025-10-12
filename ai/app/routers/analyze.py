from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from app.database import get_db, generate_id
from app.models import Image, Analysis
from app.schemas import AnalyzeRequest, AnalyzeResponse
from app.services.segmentation import SegmentationService
from datetime import datetime
import os
from app.config import settings

router = APIRouter()
segmentation_service = SegmentationService()

def process_analysis(job_id: str, image_id: str, crop: str, db: Session):
    try:
        analysis = db.query(Analysis).filter(Analysis.job_id == job_id).first()
        if not analysis:
            return
        
        analysis.status = "processing"
        db.commit()
        
        image_record = db.query(Image).filter(Image.image_id == image_id).first()
        if not image_record:
            analysis.status = "failed"
            db.commit()
            return
        
        image_path = image_record.file_path
        if not os.path.exists(image_path):
            analysis.status = "failed"
            db.commit()
            return
        
        mask_path, infected_percentage = segmentation_service.segment_infection(image_path, image_id)
        
        diseases, confidence = segmentation_service.classify_disease(image_path, crop)
        
        severity = segmentation_service.determine_severity(infected_percentage)
        
        analysis.mask_path = mask_path
        analysis.infected_area_pct = infected_percentage
        analysis.severity = severity
        analysis.top_diseases = diseases
        analysis.confidence = confidence
        analysis.status = "done"
        analysis.completed_at = datetime.utcnow()
        
        db.commit()
        
    except Exception as e:
        print(f"Error processing analysis {job_id}: {e}")
        analysis = db.query(Analysis).filter(Analysis.job_id == job_id).first()
        if analysis:
            analysis.status = "failed"
            db.commit()

@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_image(
    request: AnalyzeRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    image_record = db.query(Image).filter(Image.image_id == request.image_id).first()
    if not image_record:
        raise HTTPException(status_code=404, detail="Image not found")
    
    job_id = f"job_{generate_id()}"
    
    analysis = Analysis(
        job_id=job_id,
        image_id=request.image_id,
        crop=request.crop,
        status="pending"
    )
    
    db.add(analysis)
    db.commit()
    
    background_tasks.add_task(process_analysis, job_id, request.image_id, request.crop, db)
    
    return AnalyzeResponse(
        job_id=job_id,
        status="pending"
    )

@router.get("/analyze/{job_id}", response_model=AnalyzeResponse)
async def get_analysis_result(job_id: str, db: Session = Depends(get_db)):
    analysis = db.query(Analysis).filter(Analysis.job_id == job_id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis job not found")
    
    response_data = {
        "job_id": job_id,
        "status": analysis.status
    }
    
    if analysis.status == "done":
        mask_url = f"https://{settings.AWS_S3_BUCKET}.s3.{settings.AWS_REGION}.amazonaws.com/masks/{analysis.image_id}_overlay.png"
        # mask_url = f"https://testimagesuat.s3.ap-south-1.amazonaws.com/masks/{analysis.image_id}_overlay.png"
        
        response_data["results"] = {
            "mask_url": mask_url,
            "infected_area_pct": analysis.infected_area_pct,
            "severity": analysis.severity,
            "top_diseases": analysis.top_diseases,
            "confidence": analysis.confidence
        }
    
    return AnalyzeResponse(**response_data)