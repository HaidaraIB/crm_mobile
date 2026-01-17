# تحديث Firebase بعد تغيير Package Name

## المشكلة
بعد تغيير `applicationId` من `com.example.crm_mobile` إلى `com.loopcrm.mobile`، يجب تحديث إعدادات Firebase.

## ✅ الحل المطبق
تم تحديث `google-services.json` يدوياً لتغيير `package_name` إلى `com.loopcrm.mobile`.

## ⚠️ خطوات إضافية مطلوبة في Firebase Console

### الطريقة 1: إضافة تطبيق جديد (موصى به)

1. انتقل إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `crm-mobile-409dc`
3. انقر على إعدادات المشروع (⚙️) > **Project settings**
4. في قسم **Your apps**، انقر على **Add app** > **Android**
5. أدخل:
   - **Package name**: `com.loopcrm.mobile`
   - **App nickname**: LOOP CRM (اختياري)
   - **Debug signing certificate SHA-1**: (اختياري - للحصول عليه: `keytool -list -v -keystore android/crm-release-key.jks`)
6. انقر **Register app**
7. **حمّل ملف `google-services.json` الجديد** واستبدل الملف القديم في:
   ```
   android/app/google-services.json
   ```

### الطريقة 2: تحديث التطبيق الموجود (إذا كان متاحاً)

1. في Firebase Console، انتقل إلى **Project settings** > **Your apps**
2. إذا كان بإمكانك تعديل package name للتطبيق الموجود، قم بتحديثه
3. حمّل `google-services.json` المحدث

## 🔍 التحقق من التحديث

بعد تحديث `google-services.json`، تحقق من:

1. الملف يحتوي على `"package_name": "com.loopcrm.mobile"`
2. الملف موجود في `android/app/google-services.json`
3. جرب البناء مرة أخرى:
   ```powershell
   flutter clean
   flutter build appbundle --release
   ```

## 📝 ملاحظات

- **إذا لم تستخدم Firebase**: يمكنك إزالة Google Services plugin من `build.gradle.kts`
- **إذا استخدمت Firebase**: يجب إضافة تطبيق جديد في Firebase Console
- **SHA-1 Certificate**: للحصول عليه:
  ```powershell
  keytool -list -v -keystore android/crm-release-key.jks -alias crm-key
  ```

## 🐛 استكشاف الأخطاء

### خطأ: "No matching client found"
- تأكد من أن `package_name` في `google-services.json` يطابق `applicationId` في `build.gradle.kts`
- تأكد من تحديث Firebase Console

### خطأ: "Google Services plugin failed"
- تحقق من وجود `google-services.json` في `android/app/`
- تأكد من أن الملف صحيح JSON

---

**ملاحظة**: إذا لم تستخدم Firebase في الإنتاج، يمكنك تعطيل Google Services plugin مؤقتاً.
