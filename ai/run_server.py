#!/usr/bin/env python3

import uvicorn
import os
import sys
from dotenv import load_dotenv
load_dotenv()
def main():
    print("🌾 KhetLink AI - Crop Disease Analysis Backend")
    print("=" * 50)
    
    # Check if required directories exist
    required_dirs = ["uploads/images", "uploads/masks", "reports", "storage"]
    for dir_path in required_dirs:
        if not os.path.exists(dir_path):
            os.makedirs(dir_path, exist_ok=True)
            print(f"📁 Created directory: {dir_path}")
    
    # Check for environment variables
    groq_key = os.getenv("GROQ_API_KEY")
    print(f"groq_api_key={groq_key}")
    if not groq_key or groq_key == "your_groq_api_key_here":
        print("⚠️  WARNING: GROQ_API_KEY not set. Chat functionality will use fallback responses.")
        print("   Please set your Groq API key in environment variables.")
    else:
        print("✅ Groq API key found")
    
    # Check if models exist
    if os.path.exists("plant_disease_model.h5"):
        print("✅ Found plant_disease_model.h5")
    elif os.path.exists("plant_disease_model.pt"):
        print("✅ Found plant_disease_model.pt")
    else:
        print("⚠️  No disease classification model found. Using fallback disease database.")
        print("   Place your model as 'plant_disease_model.h5' or 'plant_disease_model.pt' in root directory.")
    
    print("\n🚀 Starting server on http://localhost:8000")
    print("📚 API Documentation: http://localhost:8000/docs")
    print("🔧 Alternative docs: http://localhost:8000/redoc")
    print("\nPress Ctrl+C to stop the server")
    print("=" * 50)
    
    try:
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=8085,
            reload=True,
            log_level="info"
        )
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")
        sys.exit(0)

if __name__ == "__main__":
    main()