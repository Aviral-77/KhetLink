"""
Nokia Number Verification Router

Usage in main.py:
    from nokia_verify_router import router as nokia_router
    app.include_router(nokia_router, prefix="/api/v1", tags=["verification"])
"""

import os
import requests
import urllib.parse
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Create router
router = APIRouter()

# --- Config ---
RAPIDAPI_KEY = os.getenv("RAPIDAPI_KEY")  # Set via environment variable
REDIRECT_URI = os.getenv("REDIRECT_URI", "https://teambhoomitech.requestcatcher.com/test/")
RAPIDAPIHOST = "network-as-code.nokia.rapidapi.com"

# --- URLs ---
NAC_CLIENT_CREDENTIALS_URL = "https://network-as-code.p-eu.rapidapi.com/oauth2/v1/auth/clientcredentials"
WELL_KNOWN_METADATA_URL = "https://network-as-code.p-eu.rapidapi.com/.well-known/openid-configuration"
NUMBER_VERIFICATION_URL = "https://network-as-code.p-eu.rapidapi.com/passthrough/camara/v1/number-verification/number-verification/v0/verify"


# --- Request/Response Models ---
class VerificationRequest(BaseModel):
    phone_number: str = Field(..., description="Phone number without + prefix", example="99999991004")

    class Config:
        json_schema_extra = {
            "example": {
                "phone_number": "99999991004"
            }
        }


class VerificationResponse(BaseModel):
    validated: bool = Field(..., description="Whether the phone number was verified")
    phone_number: str = Field(..., description="The phone number that was verified")
    message: Optional[str] = Field(None, description="Status message")

    class Config:
        json_schema_extra = {
            "example": {
                "validated": True,
                "phone_number": "99999991004",
                "message": "Verification successful"
            }
        }


class HealthResponse(BaseModel):
    status: str
    api_key_configured: bool
    redirect_uri: str


# --- Helper Functions ---
def get_client_credentials():
    """Get OAuth client credentials from Nokia API"""
    headers = {
        "content-type": "application/json",
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPIHOST,
    }
    r = requests.get(NAC_CLIENT_CREDENTIALS_URL, headers=headers, timeout=30)
    if r.status_code != 200:
        raise Exception(f"Error getting credentials: {r.status_code} {r.text}")
    
    creds = r.json()
    client_id = creds.get("client_id")
    client_secret = creds.get("client_secret")
    
    if not client_id or not client_secret:
        raise Exception("Missing client_id or client_secret in response")
    
    return client_id, client_secret


def get_endpoints():
    """Get OAuth endpoints from OIDC metadata"""
    headers = {
        "content-type": "application/json",
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPIHOST,
    }
    r = requests.get(WELL_KNOWN_METADATA_URL, headers=headers, timeout=30)
    if r.status_code != 200:
        raise Exception(f"Error getting endpoints: {r.status_code} {r.text}")
    
    meta = r.json()
    auth_endpoint = meta.get("authorization_endpoint")
    token_endpoint = meta.get("token_endpoint")
    
    if not auth_endpoint or not token_endpoint:
        raise Exception("Missing authorization_endpoint or token_endpoint in metadata")
    
    return auth_endpoint, token_endpoint


def get_authorization_code(auth_endpoint: str, client_id: str, phone_number: str):
    """Get authorization code by simulating the OAuth flow"""
    params = {
        "scope": "number-verification:verify",
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "state": "App-state",
        "login_hint": f"+{phone_number}",
    }
    
    auth_url = f"{auth_endpoint}?{urllib.parse.urlencode(params)}"
    logger.info(f"Authorization URL: {auth_url}")
    
    try:
        # Follow redirects to get authorization code
        resp = requests.get(auth_url, allow_redirects=True, timeout=30)
        final_url = resp.url
        parsed = urllib.parse.urlparse(final_url)
        qs = urllib.parse.parse_qs(parsed.query)
        auth_code = qs.get("code", [None])[0]
        
        if not auth_code:
            raise Exception("Authorization code not found in redirect URL")
        
        return auth_code
    except Exception as e:
        logger.error(f"Error getting authorization code: {str(e)}")
        raise


def get_access_token(token_endpoint: str, client_id: str, client_secret: str, auth_code: str):
    """Exchange authorization code for access token"""
    data = {
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "authorization_code",
        "code": auth_code,
        "redirect_uri": REDIRECT_URI,
    }
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    
    r = requests.post(token_endpoint, data=data, headers=headers, timeout=30)
    if r.status_code != 200:
        raise Exception(f"Error getting access token: {r.status_code} {r.text}")
    
    token_data = r.json()
    access_token = token_data.get("access_token")
    
    if not access_token:
        raise Exception("Access token not present in token response")
    
    return access_token


def verify_phone_number_with_token(access_token: str, phone_number: str):
    """Verify phone number using access token"""
    headers = {
        "content-type": "application/json",
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPIHOST,
        "Authorization": f"Bearer {access_token}",
    }
    payload = {"phoneNumber": f"+{phone_number}"}
    
    r = requests.post(NUMBER_VERIFICATION_URL, json=payload, headers=headers, timeout=30)
    
    logger.info(f"Verification status: {r.status_code}")
    
    if r.status_code != 200:
        raise Exception(f"Verification failed with status {r.status_code}: {r.text}")
    
    try:
        body = r.json()
        verified = body.get("devicePhoneNumberVerified") or body.get("phoneNumberVerified") or False
        return verified
    except Exception:
        return False


# --- Router Endpoints ---
@router.post("/verify", response_model=VerificationResponse, summary="Verify Phone Number")
async def verify_number(request: VerificationRequest):
    """
    Verify a phone number using Nokia Network-as-Code API.
    
    **Parameters:**
    - **phone_number**: Phone number without country code prefix (e.g., "99999991004")
    
    **Returns:**
    - **validated**: Boolean indicating if the number was verified
    - **phone_number**: The verified phone number
    - **message**: Status message
    """
    phone_number = request.phone_number.strip()
    
    # Remove + or country code if provided
    phone_number = phone_number.lstrip("+")
    
    if not phone_number:
        raise HTTPException(status_code=400, detail="Phone number cannot be empty")
    
    try:
        logger.info(f"Starting verification for phone number: {phone_number}")
        
        # Step 1: Get client credentials
        logger.info("Getting client credentials...")
        client_id, client_secret = get_client_credentials()
        
        # Step 2: Get OAuth endpoints
        logger.info("Getting OAuth endpoints...")
        auth_endpoint, token_endpoint = get_endpoints()
        
        # Step 3: Get authorization code
        logger.info("Getting authorization code...")
        auth_code = get_authorization_code(auth_endpoint, client_id, phone_number)
        
        # Step 4: Get access token
        logger.info("Getting access token...")
        access_token = get_access_token(token_endpoint, client_id, client_secret, auth_code)
        
        # Step 5: Verify phone number
        logger.info("Verifying phone number...")
        validated = verify_phone_number_with_token(access_token, phone_number)
        
        logger.info(f"Verification result: {validated}")
        
        return VerificationResponse(
            validated=validated,
            phone_number=phone_number,
            message="Verification successful" if validated else "Verification failed"
        )
        
    except Exception as e:
        logger.error(f"Verification error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Verification failed: {str(e)}"
        )


@router.get("/health", response_model=HealthResponse, summary="Health Check")
async def health_check():
    """
    Check the health status of the Nokia verification service.
    
    **Returns:**
    - **status**: Service status
    - **api_key_configured**: Whether the API key is configured
    - **redirect_uri**: The configured redirect URI
    """
    return HealthResponse(
        status="healthy",
        api_key_configured=bool(RAPIDAPI_KEY),
        redirect_uri=REDIRECT_URI
    )