# 🔥 إعداد Firebase Push Notifications لـ iOS في Codemagic

## 📋 نظرة عامة

هذا الدليل يشرح كيفية إعداد Firebase Cloud Messaging (FCM) للإشعارات الدفعية في iOS عند البناء باستخدام Codemagic.

---

## ✅ ما تم إعداده بالفعل في المشروع

### 1. ملفات المشروع
- ✅ `ios/Runner/AppDelegate.swift` - مُعد مع Firebase و FCM
- ✅ `ios/Podfile` - يحتوي على Firebase dependencies
- ✅ `ios/Runner/Runner.entitlements` - ملف entitlements لـ Push Notifications
- ✅ `ios/Runner/GoogleService-Info.plist` - موجود محلياً (لكن في `.gitignore`)

### 2. الكود
- ✅ Firebase initialization في `AppDelegate.swift`
- ✅ APNs token handling
- ✅ FCM token handling
- ✅ Notification permissions request

---

## ⚠️ المشكلة: GoogleService-Info.plist

ملف `GoogleService-Info.plist` موجود في `.gitignore` لأسباب أمنية، لذلك **لن يُرفع إلى Git**. عند البناء في Codemagic، يجب إنشاء هذا الملف تلقائياً من Environment Variable.

---

## 🔧 الحل: إعداد Codemagic

### الخطوة 1: الحصول على محتوى GoogleService-Info.plist

1. افتح ملف `ios/Runner/GoogleService-Info.plist` محلياً
2. انسخ **المحتوى الكامل** للملف (XML كامل)

### الخطوة 2: إضافة Environment Variable في Codemagic

1. اذهب إلى Codemagic → **Settings** → **Environment variables**
2. أضف متغير جديد:
   - **Variable name**: `GOOGLE_SERVICE_INFO_PLIST`
   - **Variable value**: الصق محتوى ملف `GoogleService-Info.plist` كاملاً
   - **Group**: `ios_config` (نفس مجموعة BASE_URL و API_KEY)
   - **Secure**: ✅ نعم (لحماية البيانات الحساسة)

### الخطوة 3: التحقق من codemagic.yaml

تأكد من أن `codemagic.yaml` يحتوي على:

```yaml
groups:
  - ios_config # BASE_URL, API_KEY, and GOOGLE_SERVICE_INFO_PLIST
```

وسكريبت إنشاء الملف:

```yaml
- name: Create GoogleService-Info.plist for Firebase
  script: |
    if [ -n "$GOOGLE_SERVICE_INFO_PLIST" ]; then
      echo "$GOOGLE_SERVICE_INFO_PLIST" > ios/Runner/GoogleService-Info.plist
      echo "✅ Created GoogleService-Info.plist from environment variable"
    else
      echo "⚠️ Warning: GOOGLE_SERVICE_INFO_PLIST not set."
    fi
```

✅ **تم إضافته بالفعل في `codemagic.yaml`**

---

## 🔐 إعداد APNs في Apple Developer Portal

### الخطوة 1: تفعيل Push Notifications في App ID

1. اذهب إلى [Apple Developer Portal](https://developer.apple.com/account/)
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. اختر App ID: `com.loopcrm.mobile`
4. فعّل **Push Notifications** → **Save**

### الخطوة 2: إنشاء APNs Key (الطريقة الموصى بها)

1. في Apple Developer Portal → **Keys** → **+**
2. **Key Name**: `APNs Key for CRM Mobile`
3. فعّل **Apple Push Notifications service (APNs)**
4. اضغط **Continue** → **Register**
5. **Download** ملف `.p8` واحفظه في مكان آمن
6. سجل:
   - **Key ID** (مثل: ABC123DEFG)
   - **Team ID** (مثل: XYZ987654)

### الخطوة 3: رفع APNs Key إلى Firebase

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر المشروع → **Project Settings** → **Cloud Messaging**
3. في قسم **iOS app configuration**:
   - اختر **APNs Authentication Key**
   - ارفع ملف `.p8`
   - أدخل **Key ID**
   - أدخل **Team ID**
   - اضغط **Upload**

---

## 📱 إعداد Capabilities في Xcode (مطلوب مرة واحدة)

**ملاحظة**: هذه الخطوة تحتاج Mac و Xcode. إذا لم يكن لديك Mac، يمكنك:
- استخدام Mac في السحابة
- طلب من مطور آخر لديه Mac
- استخدام Codemagic's automatic capabilities (قد يعمل تلقائياً)

### الخطوات:

1. افتح `ios/Runner.xcworkspace` في Xcode
2. اختر Target: **Runner**
3. تبويب **Signing & Capabilities**
4. اضغط **+ Capability** وأضف:
   - ✅ **Push Notifications**
   - ✅ **Background Modes** → فعّل **Remote notifications**

### التحقق من Entitlements

تأكد من أن `ios/Runner/Runner.entitlements` يحتوي على:

```xml
<key>aps-environment</key>
<string>production</string>
```

✅ **تم إنشاؤه بالفعل**

---

## 🧪 الاختبار

### 1. اختبار محلياً

```bash
flutter run --release
```

تحقق من Console logs:
- يجب أن ترى: `Firebase registration token: [token]`
- يجب أن يطلب التطبيق أذونات الإشعارات

### 2. اختبار في Codemagic

1. شغّل build في Codemagic
2. راجع سجلات البناء:
   - يجب أن ترى: `✅ Created GoogleService-Info.plist from environment variable`
   - يجب أن يكتمل البناء بنجاح

### 3. اختبار Push Notifications

1. في Firebase Console → **Cloud Messaging** → **Send test message**
2. أدخل FCM Token (من Console logs في التطبيق)
3. أرسل رسالة اختبار
4. يجب أن تصل الإشعار على الجهاز

---

## 🐛 استكشاف الأخطاء

### خطأ: "GoogleService-Info.plist not found"

**الحل:**
- تأكد من إضافة `GOOGLE_SERVICE_INFO_PLIST` في Codemagic Environment Variables
- تأكد من أن المجموعة `ios_config` مضاف في `codemagic.yaml`
- تحقق من سجلات البناء في Codemagic

### خطأ: "Firebase registration token is nil"

**الحل:**
- تأكد من أن APNs Key مرفوع في Firebase Console
- تأكد من أن Push Notifications capability مفعلة في Xcode
- تأكد من أن `aps-environment` مضبوط على `production` في entitlements

### خطأ: "Failed to register for remote notifications"

**الحل:**
- تحقق من أذونات الإشعارات في إعدادات الجهاز
- تأكد من أن التطبيق يطلب الأذونات بشكل صحيح
- تأكد من أن Background Modes → Remote notifications مفعلة

### خطأ: "APNs token not set"

**الحل:**
- تأكد من أن APNs certificate/key مرفوع في Firebase
- تأكد من أن Bundle ID في Firebase يطابق Bundle ID في المشروع
- تحقق من أن App ID في Apple Developer Portal مفعل عليه Push Notifications

---

## 📋 Checklist

### في Codemagic:
- [ ] `GOOGLE_SERVICE_INFO_PLIST` موجود في Environment Variables
- [ ] المتغير في مجموعة `ios_config`
- [ ] المتغير marked as Secure
- [ ] `codemagic.yaml` يحتوي على سكريبت إنشاء GoogleService-Info.plist

### في Apple Developer Portal:
- [ ] Push Notifications مفعلة في App ID
- [ ] APNs Key تم إنشاؤه ورفعه إلى Firebase
- [ ] Team ID و Key ID مسجلين

### في Firebase Console:
- [ ] APNs Authentication Key مرفوع
- [ ] Bundle ID في Firebase يطابق Bundle ID في المشروع
- [ ] تم اختبار إرسال إشعار تجريبي

### في Xcode (إذا كان متاحاً):
- [ ] Push Notifications capability مضاف
- [ ] Background Modes → Remote notifications مفعل
- [ ] Runner.entitlements يحتوي على `aps-environment`

---

## 📚 موارد إضافية

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [APNs Authentication Key Guide](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Codemagic iOS Build Guide](https://docs.codemagic.io/yaml/building/yaml-getting-started/)

---

## 💡 نصائح مهمة

1. **احفظ APNs Key**: احفظ ملف `.p8` في مكان آمن - لن تتمكن من تحميله مرة أخرى
2. **استخدم Production APNs**: للتطبيقات المنشورة، استخدم Production APNs Key
3. **اختبر على TestFlight**: اختبر Push Notifications على TestFlight قبل النشر
4. **راقب Firebase Console**: راجع Firebase Console → Cloud Messaging → Reports لمراقبة الإشعارات

---

**آخر تحديث**: يناير 2026
