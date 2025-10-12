# KhetLink — Smart Agriculture Ecosystem

An integrated ecosystem connecting farmers, agribusinesses, and experts through AI-driven insights, verified geospatial data, and smart digital services — fostering transparency, productivity, and sustainability across the agricultural value chain.

## Platform overview

KhetLink combines carrier-verified network APIs, AI-powered analysis, and a Flutter client to deliver mapped, verified and actionable agriculture workflows: disease detection, farm mapping, insurance claims, carbon credits and a verified marketplace.

---

## 🚀 Core Features (segregated)

KhetLink's core capabilities are grouped into four focused pillars below.

### 🤖 AI (Disease Detection & Insights)

- Crop Disease Detection: Deep learning models analyze leaf images for disease type, severity, affected area and treatment recommendations.
- Segmentation: AI-generated masks and overlays to quantify affected areas.
- Models Used: Utilizes FastSAM for segmentation and PyTorch/TensorFlow models trained on regional crop disease datasets.
- Multilingual Chatbot: LLM-powered assistant (Hindi & English) to answer farmer questions and provide next steps.
- Weather Integration: Field-specific forecasts to guide treatments and operations.

### 🌱 Carbon Credits

- Carbon Credit Tracking: Continuous verification of sustainable practices and farm boundaries for credit issuance.
- Importance: Carbon credits incentivize environmentally friendly farming by allowing farmers to earn for sustainable practices, reduce greenhouse gas emissions, and participate in verified carbon markets.
- Carrier-verified location trails and KYC-backed ownership improve trust in listed credits.

### 🛒 Marketplace

- Farmer Marketplace: B2B/B2C listing and discovery with verified seller/buyer identities.
- Fraud Reduction: KYC + network-level phone verification to prevent fake accounts and listings.

### 🧾 Insurance Claims

- Claims Automation: Auto-generated PDF reports containing AI analysis, network-verified location, time, and KYC metadata.
- Tamper-evident reports and audit trails reduce fraudulent payouts and speed claims processing.

---

## Project structure

```
khetlink/
│
├── ai/                          # AI backend
│   ├── app/
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── database.py
│   │   ├── main.py
│   │   ├── routers/
│   │   │   ├── upload.py
│   │   │   ├── analyze.py
│   │   │   ├── images.py
│   │   │   ├── chat.py
│   │   │   └── claims.py
│   │   └── services/
│   │       ├── segmentation.py
│   │       ├── llm_service.py
│   │       ├── pdf_service.py
│   │       └── directory_service.py
│   ├── uploads/
│   ├── reports/
│   ├── storage/
│   ├── requirements.txt
│   ├── run_server.py
│   └── .env.example
│
├── flutter_app/                 # Flutter mobile & web client
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config.dart
│   │   ├── api_service.dart
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   ├── assets/
│   ├── test/
│   └── pubspec.yaml
│
└── README.md
```

---

## Backend setup (AI & APIs)

Prerequisites
- Python 3.9+
- pip

Quick start (Windows PowerShell)

```powershell
cd ai
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python run_server.py
```

Default server: http://localhost:8085

Create `ai/.env` from `.env.example` and set keys like `NOKIA_CLIENT_ID`, `NOKIA_CLIENT_SECRET`, `GROQ_API_KEY`, and `DATABASE_URL`.

Notes
- FastAPI projects often expose `/docs` (Swagger) and `/redoc`. If `run_server.py` uses `uvicorn app.main:app`, visit those endpoints when the server runs.
- Configure persistent storage (S3) and a production database for production use.

---

## Mobile Application setup (Flutter)

Prerequisites
- Flutter SDK (stable)
- Android Studio / Xcode (for mobile builds)
- Visual Studio for Windows desktop builds

Quick start (PowerShell)

```powershell
cd flutter_app
flutter pub get
flutter run -d windows   # or -d chrome, -d android, -d ios
```

Edit `flutter_app/lib/config.dart` to point `apiBaseUrl` at your running backend, e.g. `http://localhost:8085`.

Testing

```powershell
cd flutter_app
flutter test
flutter analyze
```

---

## API quick reference

- POST /upload-photo — upload image + phone + farmer id (multipart/form-data)
- POST /analyze — run disease analysis for an `image_id`
- GET /image/{image_id} — original image
- GET /mask/{image_id} — segmentation mask
- POST /chat-query — multilingual chat (Hindi/English)
- POST /verify-phone — network-level phone verification
- POST /verify-location — carrier-verified location retrieval
- POST /verify-kyc — KYC / Aadhaar match
- POST /download-claim — generate verified claim PDF

Refer to `ai/app/routers/` for exact payloads and response schemas.

Example (PowerShell chat request)

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8085/chat-query -Body (@{farmer_id='farmer_123'; question='क्या मेरी फसल बचाई जा सकती है?'; lang='hi'} | ConvertTo-Json) -ContentType 'application/json'
```

---

## Technology stack (high level)

- Network APIs: Nokia Open Gateway (carrier-level location, phone verification, KYC)
- Backend: FastAPI, SQLAlchemy, ReportLab
- AI: FastSAM (segmentation), PyTorch/TensorFlow (models), OpenCV
- Chatbot: Groq LLM (multilingual)
- Mobile App: Flutter (mobile, web, desktop)

---

## Supported crops (example)

| Crop  | Example diseases                                  | Example accuracy |
|-------|---------------------------------------------------|------------------:|
| Tomato| Late Blight, Early Blight, Leaf Curl, Bacterial Spot | 94%              |
| Rice  | Brown Spot, Leaf Blast, Bacterial Blight           | 91%              |
| Wheat | Rust, Powdery Mildew, Septoria                     | 89%              |

Extensible to 20+ crops with regional datasets.

---

## Deployment (concise)

Backend (Docker example)

```bash
docker build -t khetlink-ai ./ai
docker run -p 8085:8085 --env-file ai/.env -v %cd%/ai/storage:/app/storage khetlink-ai
```

Enable HTTPS with NGINX + Let's Encrypt for production. Host models and reports on cloud storage.

Mobile Application: standard Flutter build flows (APK/IPA/web builds). Deploy web bundles to Firebase/Vercel/Netlify.

---

## Roadmap (selected)

- Expand crop support and regional disease datasets
- Offline inference (TensorFlow Lite / TFLite)
- Blockchain traceability for carbon credits (optional)
- Drone-based surveys and predictive analytics

---

## Project impact (projected)

| Metric | Before KhetLink | With KhetLink |
|--------:|----------------:|--------------:|
| Claim processing time | 14 days | 2 days |
| Fraudulent claims | 15–20% | <2% |
| Farmer onboarding time | 5–10 min | ~30 sec |

---