# Building Production APK - Step by Step Guide

## Prerequisites
- Flutter SDK installed and configured
- Java JDK installed (for keytool)
- Android SDK configured

## Step 1: Create a Keystore File

Open PowerShell or Command Prompt and navigate to the `android` folder:

```powershell
cd C:\Users\ASUS\Desktop\CRM\crm_mobile\android
```

Run the following command to create a keystore file. **Replace the values with your own information:**

```powershell
keytool -genkey -v -keystore crm-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias crm-key
```

You will be prompted to enter:
- **Keystore password**: Choose a strong password (remember this!)
- **Key password**: Usually same as keystore password (remember this!)
- **Your name**: Your name or company name
- **Organizational Unit**: Your department/team
- **Organization**: Your company name
- **City**: Your city
- **State**: Your state/province
- **Country code**: Two-letter country code (e.g., US, EG, SA)

**Important:** Save these passwords securely! You'll need them for future updates.

## Step 2: Create/Update .env File for Production

**IMPORTANT:** Before building the production APK, you need to create a `.env` file in the project root with your production API configuration.

Create or update `.env` file in the project root (`C:\Users\ASUS\Desktop\CRM\crm_mobile\.env`):

```env
BASE_URL=https://api.yourdomain.com/api
API_KEY=your_production_api_key_here
```

**Example:**
```env
BASE_URL=https://haidaraib.pythonanywhere.com/api
API_KEY=your_actual_production_api_key
```

**Notes:**
- The `.env` file is already configured in `pubspec.yaml` to be bundled with the app
- Make sure to use your **production** API URL and API key (not development/local values)
- The `.env` file is in `.gitignore` for security, so it won't be committed to version control
- This file will be included in the APK bundle, so use production credentials

## Step 3: Update key.properties File

Open `android/key.properties` and replace the placeholder values with your actual keystore information:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=crm-key
storeFile=crm-release-key.jks
```

**Example:**
```properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=crm-key
storeFile=crm-release-key.jks
```

## Step 4: Build the Production APK

Navigate to the project root directory:

```powershell
cd C:\Users\ASUS\Desktop\CRM\crm_mobile
```

### Option A: Build APK (Recommended for testing)
```powershell
flutter build apk --release
```

The APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### Option B: Build App Bundle (AAB) for Google Play Store
```powershell
flutter build appbundle --release
```

The AAB will be located at:
`build/app/outputs/bundle/release/app-release.aab`

## Step 5: Verify the Build

1. Check the build output for any errors
2. The APK/AAB file should be created successfully
3. You can install the APK on a device to test it

## Troubleshooting

### Error: "key.properties file not found"
- Make sure `key.properties` exists in the `android` folder
- Check that the file path is correct

### Error: "Keystore file not found"
- Make sure `crm-release-key.jks` exists in the `android` folder
- Verify the `storeFile` path in `key.properties` is correct

### Error: "Wrong password"
- Double-check your passwords in `key.properties`
- Make sure there are no extra spaces or special characters

### Error: "Build failed"
- Run `flutter clean` and try again
- Make sure all dependencies are installed: `flutter pub get`
- Check that your Flutter SDK is up to date: `flutter doctor`

### Error: ".env file not found" or API connection issues
- Make sure `.env` file exists in the project root directory
- Verify `BASE_URL` and `API_KEY` are set correctly in `.env`
- Check that the production API URL is accessible
- The app will use default values if `.env` is missing, but you should use production values

## Security Notes

⚠️ **IMPORTANT:**
- Never commit `key.properties`, `.jks`, or `.env` files to version control
- Keep your keystore file and passwords secure
- If you lose the keystore, you cannot update your app on Google Play Store
- Consider backing up your keystore file in a secure location
- **Security Note:** The `.env` file will be bundled in the APK. Anyone who extracts the APK can potentially read these values. For highly sensitive API keys, consider using:
  - Backend proxy/API gateway to hide the actual API key
  - OAuth2 or other authentication methods
  - Build flavors with different configurations

## Next Steps

After building the APK:
1. Test the APK on a physical device
2. If everything works, you can distribute the APK
3. For Google Play Store, use the AAB file instead of APK

