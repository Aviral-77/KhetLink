from sqlalchemy import Column, String, DateTime, Float, Integer, Text, Boolean, JSON
from app.database import Base
from datetime import datetime

class Farmer(Base):
    __tablename__ = "farmers"
    
    farmer_id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    location = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Image(Base):
    __tablename__ = "images"
    
    image_id = Column(String, primary_key=True, index=True)
    farmer_id = Column(String, index=True)
    crop = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    capture_ts = Column(DateTime, nullable=True)
    upload_ts = Column(DateTime, default=datetime.utcnow)

class Analysis(Base):
    __tablename__ = "analyses"
    
    job_id = Column(String, primary_key=True, index=True)
    image_id = Column(String, index=True)
    crop = Column(String, nullable=False)
    status = Column(String, default="pending")
    mask_path = Column(String, nullable=True)
    infected_area_pct = Column(Float, nullable=True)
    severity = Column(String, nullable=True)
    top_diseases = Column(JSON, nullable=True)
    confidence = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)

class ChatQuery(Base):
    __tablename__ = "chat_queries"
    
    query_id = Column(String, primary_key=True, index=True)
    farmer_id = Column(String, index=True)
    image_id = Column(String, index=True)
    question = Column(Text, nullable=False)
    language = Column(String, default="en")
    answer = Column(Text, nullable=True)
    actions = Column(JSON, nullable=True)
    confidence = Column(Float, nullable=True)
    extracted_facts = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class ClaimReport(Base):
    __tablename__ = "claim_reports"
    
    claim_id = Column(String, primary_key=True, index=True)
    farmer_id = Column(String, index=True)
    image_id = Column(String, index=True)
    pdf_path = Column(String, nullable=False)
    include_mask = Column(Boolean, default=True)
    include_location = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)