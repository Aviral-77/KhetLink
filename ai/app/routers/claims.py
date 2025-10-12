from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.database import get_db, generate_id
from app.models import ClaimReport, Image, Analysis
from app.schemas import DownloadClaimRequest, DownloadClaimResponse
from app.services.pdf_service import PDFService
import os

router = APIRouter()
pdf_service = PDFService()

@router.post("/download-claim", response_model=DownloadClaimResponse)
async def download_claim(
    request: DownloadClaimRequest,
    db: Session = Depends(get_db)
):
    image_record = db.query(Image).filter(Image.image_id == request.image_id).first()
    if not image_record:
        raise HTTPException(status_code=404, detail="Image not found")
    
    if image_record.farmer_id != request.farmer_id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    analysis = db.query(Analysis).filter(
        Analysis.image_id == request.image_id,
        Analysis.status == "done"
    ).first()
    
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found or not completed")
    
    claim_id = f"claim_{generate_id()}"
    
    mask_path = analysis.mask_path if request.include_mask else None
    
    mask_dir = os.path.dirname(analysis.mask_path) if analysis.mask_path else None
    overlay_path = None
    if mask_dir:
        overlay_path = os.path.join(mask_dir, f"{request.image_id}_overlay.png")
        if not os.path.exists(overlay_path):
            overlay_path = None
    
    try:
        pdf_path = pdf_service.generate_claim_report(
            claim_id=claim_id,
            farmer_id=request.farmer_id,
            image_path=image_record.file_path,
            mask_path=mask_path,
            overlay_path=overlay_path,
            infected_area_pct=analysis.infected_area_pct or 0.0,
            severity=analysis.severity or "Unknown",
            top_diseases=analysis.top_diseases or [],
            confidence=(analysis.confidence or 0.5) * 100,
            latitude=image_record.latitude if request.include_location else None,
            longitude=image_record.longitude if request.include_location else None,
            capture_ts=image_record.capture_ts,
            crop=image_record.crop,
            include_mask=request.include_mask,
            include_location=request.include_location
        )
    except Exception as e:
        print(f"Error generating PDF: {e}")
        raise HTTPException(status_code=500, detail="Error generating claim report")
    
    claim_record = ClaimReport(
        claim_id=claim_id,
        farmer_id=request.farmer_id,
        image_id=request.image_id,
        pdf_path=pdf_path,
        include_mask=request.include_mask,
        include_location=request.include_location
    )
    
    db.add(claim_record)
    db.commit()
    
    pdf_url = f"/claim/{claim_id}/download"
    
    return DownloadClaimResponse(
        claim_id=claim_id,
        pdf_url=pdf_url
    )

@router.get("/claim/{claim_id}/download")
async def download_claim_pdf(claim_id: str, db: Session = Depends(get_db)):
    claim_record = db.query(ClaimReport).filter(ClaimReport.claim_id == claim_id).first()
    if not claim_record:
        raise HTTPException(status_code=404, detail="Claim report not found")
    
    if not os.path.exists(claim_record.pdf_path):
        raise HTTPException(status_code=404, detail="PDF file not found")
    
    return FileResponse(
        path=claim_record.pdf_path,
        media_type="application/pdf",
        filename=f"KhetLink_Claim_{claim_id}.pdf"
    )