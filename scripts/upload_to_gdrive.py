#!/usr/bin/env python3
"""Upload build artifacts to a Google Drive folder via service account."""

from __future__ import annotations

import json
import os
import sys

from google.oauth2 import service_account # type: ignore
from googleapiclient.discovery import build # type: ignore
from googleapiclient.http import MediaFileUpload # type: ignore

DRIVE_SCOPE = "https://www.googleapis.com/auth/drive"


def upload_file(service, local_path: str, folder_id: str) -> str:
    name = os.path.basename(local_path)
    if not os.path.isfile(local_path):
        raise FileNotFoundError(f"Artifact not found: {local_path}")

    metadata = {"name": name, "parents": [folder_id]}
    media = MediaFileUpload(local_path, resumable=True)
    result = (
        service.files()
        .create(body=metadata, media_body=media, fields="id,name,webViewLink")
        .execute()
    )
    return result.get("webViewLink") or result.get("id", "")


def main() -> int:
    creds_json = os.environ.get("GDRIVE_CREDENTIALS_JSON", "").strip()
    folder_id = os.environ.get("GDRIVE_FOLDER_ID", "").strip()
    paths = [p for p in sys.argv[1:] if p.strip()]

    if not creds_json:
        print("ERROR: GDRIVE_CREDENTIALS_JSON is not set", file=sys.stderr)
        return 1
    if not folder_id:
        print("ERROR: GDRIVE_FOLDER_ID is not set", file=sys.stderr)
        return 1
    if not paths:
        print("ERROR: pass at least one file path to upload", file=sys.stderr)
        return 1

    info = json.loads(creds_json)
    credentials = service_account.Credentials.from_service_account_info(
        info, scopes=[DRIVE_SCOPE]
    )
    service = build("drive", "v3", credentials=credentials, cache_discovery=False)

    for path in paths:
        link = upload_file(service, path, folder_id)
        print(f"Uploaded {os.path.basename(path)} -> {link}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
