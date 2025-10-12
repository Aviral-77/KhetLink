from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime


class UploadPhotoRequest(BaseModel):
    farmer_id: str
    crop: str
    lat: Optional[float] = None
    lon: Optional[float] = None
    capture_ts: Optional[datetime] = None


class UploadRemoteImageRequest(BaseModel):
    image_path: str  # S3 URL
    farmer_id: str
    crop: str
    lat: Optional[float] = None
    lon: Optional[float] = None
    capture_ts: Optional[datetime] = None


class UploadPhotoResponse(BaseModel):
    image_id: str
    upload_ts: datetime


class AnalyzeRequest(BaseModel):
    image_id: str
    crop: str


class DiseaseResult(BaseModel):
    label: str
    score: float


class AnalyzeResponse(BaseModel):
    job_id: str
    status: str
    results: Optional[Dict[str, Any]] = None


class ChatQueryRequest(BaseModel):
    farmer_id: str
    image_id: str
    question: str
    infected_area_pct: Optional[float] = None
    severity: Optional[str] = None
    top_diseases: Optional[List[DiseaseResult]] = None
    lang: str = "en"


class ChatQueryResponse(BaseModel):
    answer: str
    actions: List[str]
    confidence: float
    extracted_facts: Dict[str, Any]


class DownloadClaimRequest(BaseModel):
    farmer_id: str
    image_id: str
    include_mask: bool = True
    include_location: bool = True


class DownloadClaimResponse(BaseModel):
    claim_id: str
    pdf_url: str
