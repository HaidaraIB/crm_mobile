#!/usr/bin/env python3
"""Upload build artifacts to Google Drive (Shared Drive + service account, or OAuth)."""

from __future__ import annotations

import json
import os
import sys

from google.auth.transport.requests import Request  # type: ignore
from google.oauth2 import credentials as oauth_credentials  # type: ignore
from google.oauth2 import service_account  # type: ignore
from googleapiclient.discovery import build  # type: ignore
from googleapiclient.errors import HttpError  # type: ignore
from googleapiclient.http import MediaFileUpload  # type: ignore

DRIVE_SCOPE = "https://www.googleapis.com/auth/drive"

STORAGE_QUOTA_HINT = """
Drive upload failed: service accounts have no personal Drive storage quota.

Fix (pick one):

  A) Shared Drive (recommended for service accounts)
     1. In Google Drive, create or open a Shared drive (Team drive).
        Requires Google Workspace; not available on free personal Gmail alone.
     2. Add your service account email as Content manager on that Shared drive.
     3. Create a folder inside the Shared drive and set GDRIVE_FOLDER_ID to that folder.
     4. Set GitHub secret GDRIVE_USE_SHARED_DRIVE=true

  B) OAuth (works with a normal Google account / My Drive folder)
     1. Create an OAuth client (Desktop app) in Google Cloud Console.
     2. Obtain a refresh token with Drive scope for the account that owns the folder.
     3. Set GitHub secrets: GDRIVE_AUTH_MODE=oauth, GDRIVE_OAUTH_CLIENT_ID,
        GDRIVE_OAUTH_CLIENT_SECRET, GDRIVE_OAUTH_REFRESH_TOKEN

See docs/GITHUB_ACTIONS_ANDROID_SETUP.md
"""


def _truthy(value: str) -> bool:
    return value.strip().lower() in ("1", "true", "yes", "on")


def build_drive_service():
    auth_mode = os.environ.get("GDRIVE_AUTH_MODE", "service_account").strip().lower()

    if auth_mode == "oauth":
        refresh = os.environ.get("GDRIVE_OAUTH_REFRESH_TOKEN", "").strip()
        client_id = os.environ.get("GDRIVE_OAUTH_CLIENT_ID", "").strip()
        client_secret = os.environ.get("GDRIVE_OAUTH_CLIENT_SECRET", "").strip()
        if not refresh or not client_id or not client_secret:
            raise RuntimeError(
                "OAuth mode requires GDRIVE_OAUTH_REFRESH_TOKEN, "
                "GDRIVE_OAUTH_CLIENT_ID, and GDRIVE_OAUTH_CLIENT_SECRET"
            )
        creds = oauth_credentials.Credentials(
            token=None,
            refresh_token=refresh,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=client_id,
            client_secret=client_secret,
            scopes=[DRIVE_SCOPE],
        )
        creds.refresh(Request())
        return build("drive", "v3", credentials=creds, cache_discovery=False)

    creds_json = os.environ.get("GDRIVE_CREDENTIALS_JSON", "").strip()
    if not creds_json:
        raise RuntimeError("GDRIVE_CREDENTIALS_JSON is not set")
    info = json.loads(creds_json)
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=[DRIVE_SCOPE]
    )
    return build("drive", "v3", credentials=creds, cache_discovery=False)


def upload_file(service, local_path: str, folder_id: str) -> str:
    name = os.path.basename(local_path)
    if not os.path.isfile(local_path):
        raise FileNotFoundError(f"Artifact not found: {local_path}")

    metadata = {"name": name, "parents": [folder_id]}
    media = MediaFileUpload(local_path, resumable=True)

    create_kwargs: dict = {
        "body": metadata,
        "media_body": media,
        "fields": "id,name,webViewLink",
    }
    if _truthy(os.environ.get("GDRIVE_USE_SHARED_DRIVE", "")):
        create_kwargs["supportsAllDrives"] = True

    try:
        result = service.files().create(**create_kwargs).execute()
    except HttpError as err:
        if err.resp.status == 403 and "storageQuotaExceeded" in str(err):
            print(STORAGE_QUOTA_HINT, file=sys.stderr)
        raise

    return result.get("webViewLink") or result.get("id", "")


def main() -> int:
    folder_id = os.environ.get("GDRIVE_FOLDER_ID", "").strip()
    paths = [p for p in sys.argv[1:] if p.strip()]
    auth_mode = os.environ.get("GDRIVE_AUTH_MODE", "service_account").strip().lower()

    if not folder_id:
        print("ERROR: GDRIVE_FOLDER_ID is not set", file=sys.stderr)
        return 1
    if not paths:
        print("ERROR: pass at least one file path to upload", file=sys.stderr)
        return 1
    if auth_mode == "service_account" and not os.environ.get(
        "GDRIVE_CREDENTIALS_JSON", ""
    ).strip():
        print("ERROR: GDRIVE_CREDENTIALS_JSON is not set", file=sys.stderr)
        return 1

    service = build_drive_service()

    for path in paths:
        link = upload_file(service, path, folder_id)
        print(f"Uploaded {os.path.basename(path)} -> {link}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
