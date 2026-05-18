# GitHub Actions — Android build & Google Drive upload

One-time setup so pushes to `main` build release APK/AAB and upload them to Google Drive.

Workflow file: [`.github/workflows/android-build-drive.yml`](../.github/workflows/android-build-drive.yml)

## Drive upload: choose one method

Service accounts **cannot** upload into a normal “My Drive” folder (even if you shared that folder with the service account). Google returns `storageQuotaExceeded` because the service account has **zero** storage quota.

Use **one** of these:

| Method | Best for |
|--------|----------|
| **A. Shared Drive + service account** | Google Workspace teams |
| **B. OAuth refresh token** | Personal Gmail / folder in someone’s My Drive |

---

## A. Shared Drive + service account (recommended)

### 1. Google Cloud service account

1. Open [Google Cloud Console](https://console.cloud.google.com/) and select or create a project.
2. **APIs & Services → Library** → enable **Google Drive API**.
3. **IAM & Admin → Service Accounts** → **Create service account**.
4. **Keys → Add key → JSON** → download the key file.

### 2. Shared Drive (not a regular shared folder)

1. In [Google Drive](https://drive.google.com/), open **Shared drives** (left sidebar).  
   If you do not see it, you need **Google Workspace** (not available on free personal Gmail only).
2. **New** → create a Shared drive (e.g. `LoopCRM Releases`).
3. **Manage members** → add the service account email  
   `something@your-project.iam.gserviceaccount.com`  
   as **Content manager** (or Manager).
4. Inside that Shared drive, create a folder (e.g. `Android builds`).
5. Open the folder and copy the ID from the URL:  
   `https://drive.google.com/drive/folders/FOLDER_ID_HERE`

### 3. GitHub secrets (service account path)

| Secret | Value |
|--------|--------|
| `GDRIVE_CREDENTIALS_JSON` | Full service account JSON key file |
| `GDRIVE_FOLDER_ID` | Folder ID **inside the Shared drive** |
| `GDRIVE_USE_SHARED_DRIVE` | `true` |

Do **not** set `GDRIVE_AUTH_MODE` (defaults to service account).

---

## B. OAuth (personal Google account / My Drive folder)

Use this if you do not have a Shared drive and the target folder lives in a normal user’s My Drive.

### 1. OAuth client

1. Same GCP project → **APIs & Services → Credentials**.
2. **Create credentials → OAuth client ID** → Application type **Desktop app**.
3. Note **Client ID** and **Client secret**.

### 2. Refresh token (one-time)

1. Open [OAuth 2.0 Playground](https://developers.google.com/oauthplayground/).
2. Gear icon → enable **Use your own OAuth credentials** → enter Client ID and secret.
3. In Step 1, select scope: `https://www.googleapis.com/auth/drive`
4. **Authorize APIs** → sign in as the Google account that **owns** the target folder.
5. **Exchange authorization code for tokens** → copy the **Refresh token**.

### 3. Share folder

Use a folder in that same Google account’s Drive (or shared with that account as Editor). Copy `GDRIVE_FOLDER_ID` from the folder URL.

### 4. GitHub secrets (OAuth path)

| Secret | Value |
|--------|--------|
| `GDRIVE_AUTH_MODE` | `oauth` |
| `GDRIVE_OAUTH_CLIENT_ID` | OAuth client ID |
| `GDRIVE_OAUTH_CLIENT_SECRET` | OAuth client secret |
| `GDRIVE_OAUTH_REFRESH_TOKEN` | Refresh token from playground |
| `GDRIVE_FOLDER_ID` | Target folder ID |

You do **not** need `GDRIVE_CREDENTIALS_JSON` or `GDRIVE_USE_SHARED_DRIVE` for OAuth.

---

## Android build secrets (both methods)

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of `android/crm-release-key.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | e.g. `crm-key` |
| `BASE_URL` | Production API base URL |
| `API_KEY_MOBILE` | Production mobile API key (or `API_KEY`) |
| `GOOGLE_SERVICES_JSON` | (Recommended) Full `android/app/google-services.json` |

### Encode keystore (PowerShell)

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\crm_mobile\android\crm-release-key.jks"))
```

### Encode keystore (Linux)

```bash
base64 -w0 android/crm-release-key.jks
```

## Verify

1. Set secrets for method **A** or **B** above.
2. Push to `main` or run **Actions → Android Release to Google Drive → Run workflow**.
3. Check the folder for `LoopCRM 1.6.0(19).apk` and `.aab` (version from `pubspec.yaml`).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `storageQuotaExceeded` / service account has no quota | Folder is in **My Drive** — use **Shared Drive + `GDRIVE_USE_SHARED_DRIVE=true`**, or switch to **OAuth** |
| `403` / `404` on upload | Wrong folder ID, or service account not a member of the **Shared drive** |
| Release signing failed | Check keystore secrets and `ANDROID_KEY_ALIAS` |
| Firebase errors | Add `GOOGLE_SERVICES_JSON` secret |
| Workflow did not run | Push must touch `lib/`, `android/`, or `pubspec.yaml`, or use **workflow_dispatch** |
