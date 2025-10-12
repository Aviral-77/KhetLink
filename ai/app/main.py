from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from app.database import engine, get_db
from app.models import Base
from app.routers import upload, analyze, images, chat, claims
from app.routers import verify_phone_router
import uvicorn

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="KhetLink AI - Crop Disease Analysis API",
    description="Backend API for crop disease analysis using computer vision and AI",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(upload.router, tags=["Upload"])
app.include_router(analyze.router, tags=["Analysis"])
app.include_router(images.router, tags=["Images"])
app.include_router(chat.router, tags=["Chat"])
app.include_router(claims.router, tags=["Claims"])
app.include_router(verify_phone_router.router, tags=["Phone Verification"])

@app.get("/")
async def root():
    return {
        "message": "KhetLink AI - Crop Disease Analysis API",
        "version": "1.0.0",
        "endpoints": {
            "upload": "/upload-photo",
            "analyze": "/analyze",
            "images": "/image/{image_id}",
            "masks": "/mask/{image_id}",
            "chat": "/chat-query",
            "claims": "/download-claim"
        }
    }

@app.get("/health")
async def health_check():
    return {"status": "very very healthy", "timestamp": "2025-10-05T07:35:21+05:30"}

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8085,
        reload=True
    )