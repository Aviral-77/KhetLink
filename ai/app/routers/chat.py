from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db, generate_id
from app.models import ChatQuery, Image, Analysis
from app.schemas import ChatQueryRequest, ChatQueryResponse
from app.services.llm_service import LLMService
from datetime import datetime

router = APIRouter()
llm_service = LLMService()

@router.post("/chat-query", response_model=ChatQueryResponse)
async def chat_query(
    request: ChatQueryRequest,
    db: Session = Depends(get_db)
):
    image_record = db.query(Image).filter(Image.image_id == request.image_id).first()
    if not image_record:
        raise HTTPException(status_code=404, detail="Image not found")
    
    analysis = db.query(Analysis).filter(
        Analysis.image_id == request.image_id,
        Analysis.status == "done"
    ).first()
    
    infected_area_pct = request.infected_area_pct
    severity = request.severity
    top_diseases = request.top_diseases or []
    
    if analysis and not infected_area_pct:
        infected_area_pct = analysis.infected_area_pct or 0.0
        severity = analysis.severity or "Unknown"
        top_diseases = analysis.top_diseases or []
    
    if not infected_area_pct:
        infected_area_pct = 0.0
    if not severity:
        severity = "Unknown"
    if not top_diseases:
        top_diseases = [{"label": "Unknown Disease", "score": 0.5}]
    
    try:
        answer, actions, confidence, extracted_facts = llm_service.generate_response(
            question=request.question,
            language=request.lang,
            infected_area_pct=infected_area_pct,
            severity=severity,
            top_diseases=top_diseases,
            crop=image_record.crop
        )
    except Exception as e:
        print(f"Error generating LLM response: {e}")
        raise HTTPException(status_code=500, detail="Error generating response")
    
    query_id = f"query_{generate_id()}"
    
    chat_query_record = ChatQuery(
        query_id=query_id,
        farmer_id=request.farmer_id,
        image_id=request.image_id,
        question=request.question,
        language=request.lang,
        answer=answer,
        actions=actions,
        confidence=confidence,
        extracted_facts=extracted_facts
    )
    
    db.add(chat_query_record)
    db.commit()
    
    return ChatQueryResponse(
        answer=answer,
        actions=actions,
        confidence=confidence,
        extracted_facts=extracted_facts
    )