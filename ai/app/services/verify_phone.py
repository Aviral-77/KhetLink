#!/usr/bin/env python3
"""
nokia_verify_flow.py

Python version of your NodeJS flow (requests-based).

Usage:
1. Edit RAPIDAPI_KEY and REDIRECT_URI below (or set as env vars).
2. Run: python nokia_verify_flow.py
3. If the script can't automatically capture the redirect, it will open your browser and ask
   you to paste the final redirect URL (copy from address bar).
"""

import os
import requests
import urllib.parse
import webbrowser
import sys
from typing import Optional

# --- Config (edit or use env variables) ---
RAPIDAPI_KEY = os.getenv("RAPIDAPI_KEY")  # must be provided via environment variable
REDIRECT_URI = os.getenv("REDIRECT_URI", "https://teambhoomitech.requestcatcher.com/test/")  # must match registered redirect URI
PHONE_NUMBER = os.getenv("PHONE_NUMBER", "99999991004")  # simulated test number (no +)

# --- URLs ---
NAC_CLIENT_CREDENTIALS_URL = "https://network-as-code.p-eu.rapidapi.com/oauth2/v1/auth/clientcredentials"
WELL_KNOWN_METADATA_URL = "https://network-as-code.p-eu.rapidapi.com/.well-known/openid-configuration"
NUMBER_VERIFICATION_URL = "https://network-as-code.p-eu.rapidapi.com/passthrough/camara/v1/number-verification/number-verification/v0/verify"
RAPIDAPIHOST = "network-as-code.nokia.rapidapi.com"

# Globals
CLIENT_ID = None
CLIENT_SECRET = None
AUTH_ENDPOINT = None
TOKEN_ENDPOINT = None
AUTH_CODE = None
ACCESS_TOKEN = None


def get_client_credentials():
    global CLIENT_ID, CLIENT_SECRET
    headers = {
        "content-type": "application/json",
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPIHOST,
    }
    r = requests.get(NAC_CLIENT_CREDENTIALS_URL, headers=headers, timeout=30)
    if r.status_code != 200:
        raise Exception(f"Error getting credentials: {r.status_code} {r.text}")
    creds = r.json()
    print("Client credentials response:", creds)
    CLIENT_ID = creds.get("client_id")
    CLIENT_SECRET = creds.get("client_secret")
    if not CLIENT_ID or not CLIENT_SECRET:
        raise Exception("Missing client_id or client_secret in response")


def get_endpoints():
    global AUTH_ENDPOINT, TOKEN_ENDPOINT
    headers = {
        "content-type": "application/json",
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPIHOST,
    }
    r = requests.get(WELL_KNOWN_METADATA_URL, headers=headers, timeout=30)
    if r.status_code != 200:
        raise Exception(f"Error getting endpoints: {r.status_code} {r.text}")
    meta = r.json()
    print("OIDC metadata:", meta)
    AUTH_ENDPOINT = meta.get("authorization_endpoint")
    TOKEN_ENDPOINT = meta.get("token_endpoint")
    if not AUTH_ENDPOINT or not TOKEN_ENDPOINT:
        raise Exception("Missing authorization_endpoint or token_endpoint in metadata")


def get_authorization_code():
    """
    Try to retrieve the authorization code by following redirects.
    If automatic follow fails to include a code, open browser and ask user to paste final redirect URL.
    """
    global AUTH_CODE
    params = {
        "scope": "number-verification:verify",
        "response_type": "code",
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "state": "App-state",
        "login_hint": f"%2B{PHONE_NUMBER}",
    }
    # Build auth URL (preserve percent-encoding for login_hint)
    # Note: login_hint already encoded in your Node flow as %2B..., here we give raw + and urlencode will encode it
    params["login_hint"] = f"+{PHONE_NUMBER}"
    auth_url = f"{AUTH_ENDPOINT}?{urllib.parse.urlencode(params)}"
    print("\nAuth Code URL:\n", auth_url)

    # Try to follow redirects and see if requests returns final URL with code
    try:
        print("\nAttempting to GET the auth URL and follow redirects...")
        # Allow up to 10 redirects (default). Some flows may require interactive login, which will not work here.
        resp = requests.get(auth_url, allow_redirects=True, timeout=30)
        final_url = resp.url
        print("Final URL after following redirects (requests):", final_url)
        parsed = urllib.parse.urlparse(final_url)
        qs = urllib.parse.parse_qs(parsed.query)
        AUTH_CODE = qs.get("code", [None])[0]
        if AUTH_CODE:
            print("Authorization code obtained automatically.")
            return
        else:
            print("Authorization code not present in final URL from automatic GET.")
    except Exception as e:
        print("Automatic GET for auth URL failed or did not produce code:", str(e))

    # Fall back to interactive: open browser and ask user to paste final redirect URL
    print("\nOpening browser for interactive consent. Complete login/consent in the browser.")
    try:
        webbrowser.open(auth_url)
    except Exception:
        pass

    redirect_url = input("\nAfter consent, paste the FINAL redirect URL you were sent to (copy from browser address bar):\n").strip()
    if not redirect_url:
        raise Exception("No redirect URL provided")
    parsed = urllib.parse.urlparse(redirect_url)
    qs = urllib.parse.parse_qs(parsed.query)
    AUTH_CODE = qs.get("code", [None])[0]
    if not AUTH_CODE:
        raise Exception(f"Authorization code not found in provided URL: {redirect_url}")
    print("Authorization Code:", AUTH_CODE)


def get_access_token():
    global ACCESS_TOKEN
    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "authorization_code",
        "code": AUTH_CODE,
        "redirect_uri": REDIRECT_URI,
    }
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    r = requests.post(TOKEN_ENDPOINT, data=data, headers=headers, timeout=30)
    if r.status_code != 200:
        raise Exception(f"Error getting access token: {r.status_code} {r.text}")
    token_data = r.json()
    print("Token response:", token_data)
    ACCESS_TOKEN = token_data.get("access_token")
    if not ACCESS_TOKEN:
        raise Exception("Access token not present in token response")


def verify_phone_number():
    headers = {
        "content-type": "application/json",
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPIHOST,
        "Authorization": f"Bearer {ACCESS_TOKEN}",
    }
    payload = {"phoneNumber": f"+{PHONE_NUMBER}"}
    r = requests.post(NUMBER_VERIFICATION_URL, json=payload, headers=headers, timeout=30)

    print("\nVerification HTTP status:", r.status_code)
    try:
        body = r.json()
    except Exception:
        body = r.text
    print("Verification response body:", body)

    if r.status_code != 200:
        raise Exception("Number verification returned non-200")

    verified = False
    if isinstance(body, dict):
        verified = body.get("devicePhoneNumberVerified") or body.get("phoneNumberVerified") or False

    if verified:
        print("✅ Number verification successful!")
    else:
        print("❌ Number verification unsuccessful (False).")


def main():
    if not RAPIDAPI_KEY:
        print("ERROR: Set RAPIDAPI_KEY environment variable or edit the script.")
        sys.exit(1)

    try:
        print("[1/5] Getting client credentials...")
        get_client_credentials()

        print("[2/5] Getting OIDC endpoints...")
        get_endpoints()

        print("[3/5] Getting authorization code...")
        get_authorization_code()

        print("[4/5] Getting access token...")
        get_access_token()

        print("[5/5] Verifying phone number...")
        verify_phone_number()

        print("\nDone.")
    except Exception as e:
        print("\n❌ Error:", str(e))
        # Uncomment to get full traceback for debugging:
        # import traceback; traceback.print_exc()


if __name__ == "__main__":
    main()
