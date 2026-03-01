# دليل إعداد Firebase لـ iOS (بدون Xcode)

هذا الدليل يشرح الخطوات التي تم إكمالها تلقائياً والخطوات التي تحتاج Xcode.

## ✅ ما تم إكماله تلقائياً

### 1. إضافة GoogleService-Info.plist إلى المشروع
- ✅ تم إضافة الملف إلى `ios/Runner/GoogleService-Info.plist`
- ✅ تم إضافة الملف إلى `project.pbxproj` (Xcode project file)
- ✅ تم إضافة الملف إلى Resources build phase

### 2. تحديث AppDelegate.swift
- ✅ تم إضافة `import FirebaseCore`
- ✅ تم إضافة `import FirebaseMessaging`
- ✅ تم إضافة `import UserNotifications`
- ✅ تم إضافة `FirebaseApp.configure()`
- ✅ تم إضافة طلب أذونات الإشعارات
- ✅ تم إضافة معالجة APNs token
- ✅ تم إضافة FCM Messaging delegate

### 3. إنشاء Podfile
- ✅ تم إنشاء `ios/Podfile`
- ✅ تم إضافة Firebase dependencies
- ✅ تم تعيين iOS deployment target إلى 12.0

## ⚠️ الخطوات التي تحتاج Xcode (على Mac)

### 1. تثبيت CocoaPods Dependencies

على Mac، قم بتشغيل:
```bash
cd ios
pod install
```

**ملاحظة:** إذا لم يكن لديك Mac، يمكنك:
- استخدام Mac في السحابة (MacStadium, AWS Mac instances)
- استخدام GitHub Actions مع Mac runner
- طلب من مطور آخر لديه Mac

### 2. إضافة Capabilities في Xcode

1. افتح `ios/Runner.xcworkspace` في Xcode
2. اختر Target: **Runner**
3. تبويب **Signing & Capabilities**
4. انقر **+ Capability** وأضف:
   - ✅ **Push Notifications**
   - ✅ **Background Modes** → فعّل **Remote notifications**

### 3. إعداد APNs (Apple Push Notification service)

#### أ. في Apple Developer Portal:
1. اذهب إلى [Apple Developer](https://developer.apple.com/account/)
2. **Certificates, Identifiers & Profiles**
3. **Identifiers** → اختر Bundle ID → فعّل **Push Notifications**
4. أنشئ Certificate:
   - **Development**: Apple Push Notification service SSL (Sandbox)
   - **Production**: Apple Push Notification service SSL (Sandbox & Production)

#### ب. رفع Certificate/Key إلى Firebase:
1. Firebase Console → **Project Settings** → **Cloud Messaging**
2. في قسم **iOS app configuration**:
   - **Option 1 (موصى به)**: Upload **APNs Authentication Key** (`.p8` file)
     - Key ID
     - Team ID
   - **Option 2**: Upload **APNs Certificates** (`.p12` files)
     - Development certificate
     - Production certificate

### 4. إعداد Entitlements

في Xcode:
1. **File** → **New** → **File** → **Property List**
2. اسم الملف: `Runner.entitlements`
3. أضف:
```xml
<key>aps-environment</key>
<string>development</string> <!-- أو production -->
```

### 5. Build & Run

```bash
flutter run
```

## 📝 ملاحظات مهمة

### Bundle ID
- Bundle ID الحالي: `com.example.crmMobile`
- **يُنصح بتغييره** قبل النشر إلى App Store
- يمكن تغييره في Xcode: **General** → **Bundle Identifier**

### Testing
- **Development**: استخدم Development build مع Development APNs certificate
- **Production**: استخدم App Store/TestFlight build مع Production APNs certificate

### Debugging
- تحقق من Console logs في Xcode
- تحقق من Firebase Console → Cloud Messaging → Reports
- تحقق من أن FCM Token يتم طباعته في Console

## 🔧 استكشاف الأخطاء

### المشكلة: "No Firebase App '[DEFAULT]' has been created"
**الحل:** تأكد من أن `FirebaseApp.configure()` موجود في `AppDelegate.swift`

### المشكلة: "APNs token not set"
**الحل:** 
- تأكد من أن Push Notifications capability مفعلة
- تأكد من أن APNs certificate/key مرفوع في Firebase

### المشكلة: "Failed to register for remote notifications"
**الحل:**
- تحقق من أذونات الإشعارات في إعدادات الجهاز
- تأكد من أن التطبيق يطلب الأذونات بشكل صحيح

### المشكلة: الإشعارات لا تصل على أجهزة iOS
**تحقق من التالي:**
1. **مفتاح APNs في Firebase (ضروري):**
   - Firebase Console → Project Settings → Cloud Messaging
   - في قسم iOS: رفع **APNs Authentication Key** (ملف .p8) من Apple Developer، مع إدخال Key ID و Team ID. بدون هذا لا يصل أي إشعار إلى iOS.
2. **بيئة APNs (aps-environment):**
   - في `Runner.entitlements`: استخدام `development` عند التشغيل من Xcode (Debug)، و`production` عند التوزيع عبر TestFlight أو App Store.
   - إذا كان الملف مضبوطاً على `production` فقط، الإشعارات قد لا تعمل في بناء Debug على الجهاز.
3. **توكن FCM:** تأكد أن التطبيق يرسل التوكن للخادم بعد تسجيل الدخول (يتم تلقائياً عبر `NotificationService.sendTokenToServerIfLoggedIn()`).
4. **Capabilities في Xcode:** Push Notifications و Background Modes → Remote notifications مفعلان لهدف Runner.

## 📚 الخطوات التالية

بعد إكمال الخطوات في Xcode:
1. اختبر الإشعارات من Firebase Console
2. اختبر الإشعارات من Django backend
3. تحقق من أن FCM Token يتم إرساله إلى الخادم

## روابط مفيدة

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [APNs Authentication Key](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns)
- [FlutterFire iOS Setup](https://firebase.flutter.dev/docs/overview#ios)
