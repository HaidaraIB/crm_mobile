# ملخص التغييرات لإعداد النشر على Play Store

## ✅ التغييرات المنجزة

### 1. تحديث Application ID
- **قبل**: `com.example.crm_mobile`
- **بعد**: `com.loopcrm.mobile`
- **الملفات المعدلة**:
  - `android/app/build.gradle.kts`
  - `android/app/src/main/kotlin/com/loopcrm/mobile/MainActivity.kt` (تم إنشاؤه)
  - تم حذف: `android/app/src/main/kotlin/com/example/crm_mobile/MainActivity.kt`

### 2. تفعيل ProGuard/R8
- تم تفعيل `isMinifyEnabled = true`
- تم تفعيل `isShrinkResources = true`
- تم إنشاء `android/app/proguard-rules.pro` مع قواعد مناسبة لـ Flutter

### 3. تحسين AndroidManifest.xml
- إضافة `uses-feature` للأذونات الاختيارية
- إزالة `requestLegacyExternalStorage` (لأن targetSdk = 34)
- إضافة `android:allowBackup="true"`
- إضافة `android:dataExtractionRules` و `android:fullBackupContent`
- تحديث أذونات التخزين لدعم Android 13+

### 4. إضافة ملفات النسخ الاحتياطي
- `android/app/src/main/res/xml/backup_rules.xml`
- `android/app/src/main/res/xml/data_extraction_rules.xml`

### 5. إنشاء دليل النشر
- `READMEs/PLAY_STORE_PUBLISH_GUIDE.md` - دليل شامل خطوة بخطوة

## 📋 الخطوات التالية المطلوبة منك

### 1. إنشاء Keystore
```powershell
cd C:\Users\ASUS\Desktop\CRM\crm_mobile\android
keytool -genkey -v -keystore crm-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias crm-key
```

### 2. تحديث key.properties
افتح `android/key.properties` وأضف:
```properties
storePassword=YOUR_ACTUAL_PASSWORD
keyPassword=YOUR_ACTUAL_PASSWORD
keyAlias=crm-key
storeFile=crm-release-key.jks
```

### 3. إعداد ملف .env للإنتاج
تأكد من وجود `.env` في جذر المشروع:
```env
BASE_URL=https://api.yourdomain.com/api
API_KEY=your_production_api_key
```

### 4. بناء App Bundle
```powershell
cd C:\Users\ASUS\Desktop\CRM\crm_mobile
flutter clean
flutter pub get
flutter build appbundle --release
```

### 5. رفع على Play Console
- ارفع `build/app/outputs/bundle/release/app-release.aab`
- أكمل Store listing
- أضف سياسة الخصوصية
- أكمل Data Safety section

## ⚠️ ملاحظات مهمة

1. **Application ID**: `com.loopcrm.mobile` - تأكد من أنه فريد وغير مستخدم
2. **Keystore**: احفظه في مكان آمن! فقدانه يعني عدم القدرة على تحديث التطبيق
3. **Version Code**: يجب أن يزيد مع كل إصدار جديد
4. **ProGuard**: تم تفعيله - قد تحتاج لتعديل القواعد إذا واجهت مشاكل

## 🔍 التحقق من الإعدادات

قبل البناء، تحقق من:
- [ ] `key.properties` موجود ومحدث
- [ ] `crm-release-key.jks` موجود في `android/`
- [ ] `.env` موجود مع إعدادات الإنتاج
- [ ] `pubspec.yaml` يحتوي على رقم إصدار صحيح

## 📚 المراجع

راجع `READMEs/PLAY_STORE_PUBLISH_GUIDE.md` للدليل الكامل.
