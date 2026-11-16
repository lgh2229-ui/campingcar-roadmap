"""Fail builds where a Naver Dynamic Map client ID was not configured.

Do not print the value: it is supplied through a GitHub Actions secret.
"""
import os

client_id = os.environ.get("NAVER_MAP_CLIENT_ID", "")
if not client_id or not client_id.strip():
    raise SystemExit("Missing NAVER_MAP_CLIENT_ID: configure the Naver Dynamic Map client ID in GitHub Actions secrets")
if client_id != client_id.strip() or any(c.isspace() for c in client_id):
    raise SystemExit("Invalid NAVER_MAP_CLIENT_ID: remove all whitespace")
if "apps.googleusercontent.com" in client_id or "googleusercontent" in client_id:
    raise SystemExit("NAVER_MAP_CLIENT_ID is a Google OAuth client ID, not a Naver Dynamic Map client ID")
print("Naver Dynamic Map client ID configured (value hidden)")
