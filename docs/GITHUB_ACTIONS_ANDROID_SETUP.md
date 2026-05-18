# GitHub Actions — Android build & Google Drive upload

One-time setup so pushes to `main` build release APK/AAB and upload them to your shared Google Drive folder.

Workflow file: [`.github/workflows/android-build-drive.yml`](../.github/workflows/android-build-drive.yml)

## 1. Google Cloud service account

1. Open [Google Cloud Console](https://console.cloud.google.com/) and select or create a project.
2. **APIs & Services → Library** → enable **Google Drive API**.
3. **IAM & Admin → Service Accounts** → **Create service account** (no extra IAM roles needed for Drive-only upload).
4. On the service account → **Keys** → **Add key** → **JSON** → download the key file.

## 2. Share the Drive folder

1. Open the Google Drive folder your manager uses for releases.
2. **Share** → add the service account email  
   `something@your-project.iam.gserviceaccount.com`  
   as **Editor**.
3. Copy the **folder ID** from the URL:  
   `https://drive.google.com/drive/folders/FOLDER_ID_HERE`

## 3. GitHub repository secrets

In the **crm_mobile** repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of `android/crm-release-key.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | e.g. `crm-key` |
| `BASE_URL` | Production API base URL |
| `API_KEY_MOBILE` | Production mobile API key (or use `API_KEY`) |
| `GDRIVE_CREDENTIALS_JSON` | Full JSON key file from step 1 (paste entire file) |
| `GDRIVE_FOLDER_ID` | Folder ID from step 2 |
| `GOOGLE_SERVICES_JSON` | (Recommended) Full contents of `android/app/google-services.json` |

### Encode keystore (PowerShell)

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\crm_mobile\android\crm-release-key.jks"))
```

Paste the output into `ANDROID_KEYSTORE_BASE64`.

### Encode keystore (Linux / GitHub Actions runner)

```bash
base64 -w0 android/crm-release-key.jks
```

## 4. Verify

1. Bump `version:` in `pubspec.yaml` if needed (e.g. `1.6.0+19`).
2. Push to `main` (or run **Actions → Android Release to Google Drive → Run workflow**).
3. Check the shared Drive folder for:
   - `LoopCRM 1.6.0(19).apk`
   - `LoopCRM 1.6.0(19).aab`

Names follow: `LoopCRM {versionName}({buildNumber}).apk` / `.aab` from `pubspec.yaml`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `403` / `404` on Drive upload | Folder not shared with service account, or wrong `GDRIVE_FOLDER_ID` |
| Release signing failed | Check keystore secrets and `ANDROID_KEY_ALIAS` |
| Firebase / `google-services` errors | Add `GOOGLE_SERVICES_JSON` secret |
| Workflow did not run | Push must touch `lib/`, `android/`, or `pubspec.yaml`, or use **workflow_dispatch** |
