# دليل إعداد Firebase Cloud Messaging (FCM)

هذا الدليل يشرح كيفية إعداد Firebase Cloud Messaging لإشعارات Push في تطبيق CRM.

## المتطلبات الأساسية

1. حساب Google (لإنشاء مشروع Firebase)
2. Flutter SDK مثبت
3. Android Studio أو VS Code

## خطوات الإعداد

### 1. إنشاء مشروع Firebase

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. انقر على "Add project" أو "إضافة مشروع"
3. أدخل اسم المشروع (مثلاً: "CRM Mobile")
4. اتبع التعليمات لإكمال إنشاء المشروع

### 2. إضافة تطبيق Android

1. في Firebase Console، انقر على أيقونة Android
2. أدخل معلومات التطبيق:
   - **Package name**: `com.example.crm_mobile` (يجب أن يطابق `applicationId` في `android/app/build.gradle.kts`)
   - **App nickname**: (اختياري) "CRM Mobile"
   - **Debug signing certificate SHA-1**: (اختياري للاختبار)
3. انقر "Register app"

### 3. تنزيل ملف التكوين

1. بعد تسجيل التطبيق، سيتم توفير ملف `google-services.json`
2. **انسخ هذا الملف** إلى المجلد: `android/app/`
3. تأكد من أن الملف موجود في: `android/app/google-services.json`

### 4. إضافة تطبيق iOS (اختياري)

إذا كنت تريد دعم iOS:

1. في Firebase Console، انقر على أيقونة iOS
2. أدخل معلومات التطبيق:
   - **Bundle ID**: يجب أن يطابق Bundle ID في Xcode
   - **App nickname**: (اختياري)
3. انقر "Register app"
4. **انسخ ملف `GoogleService-Info.plist`** إلى المجلد: `ios/Runner/`

### 5. تثبيت التبعيات

قم بتشغيل الأمر التالي في مجلد المشروع:

```bash
flutter pub get
```

### 6. بناء التطبيق

```bash
flutter build apk
# أو
flutter run
```

## التحقق من الإعداد

بعد تشغيل التطبيق، تحقق من:

1. في Console، يجب أن ترى رسالة: `✓ Firebase initialized successfully`
2. يجب أن ترى رسالة: `✓ Notification Service initialized`
3. يجب أن ترى رسالة: `✓ FCM Token: ...`

## إرسال الإشعارات من الخادم

### هيكل الإشعار المطلوب

عند إرسال إشعار من الخادم، يجب أن يحتوي على البيانات التالية:

```json
{
  "notification": {
    "title": "عنوان الإشعار",
    "body": "محتوى الإشعار"
  },
  "data": {
    "type": "leadAssigned",
    "lead_id": "123",
    "title": "تم تعيين عميل جديد",
    "body": "تم تعيين العميل أحمد علي لك"
  }
}
```

### أنواع الإشعارات المدعومة

- `leadAssigned` - تم تعيين عميل جديد
- `leadUpdated` - تم تحديث عميل
- `leadStatusChanged` - تغير حالة العميل
- `leadReminder` - تذكير بموعد متابعة عميل
- `dealCreated` - تم إنشاء صفقة جديدة
- `dealUpdated` - تم تحديث صفقة
- `dealClosed` - تم إغلاق صفقة
- `dealReminder` - تذكير بموعد صفقة
- `taskCreated` - تم إنشاء مهمة جديدة
- `taskCompleted` - تم إكمال مهمة
- `taskReminder` - تذكير بمهمة
- `systemUpdate` - تحديثات النظام
- `subscriptionExpiring` - انتهاء الاشتراك قريباً
- `subscriptionExpired` - انتهاء الاشتراك
- `newMessage` - رسالة جديدة
- `whatsappMessage` - رسالة واتساب
- `general` - إشعار عام

### إرسال FCM Token إلى الخادم

عند تسجيل الدخول، يجب إرسال FCM Token إلى الخادم:

```dart
final token = await NotificationService().fcmToken;
// إرسال Token إلى API
await ApiService().updateFCMToken(token);
```

## إضافة أنواع إشعارات جديدة

لإضافة نوع إشعار جديد:

1. أضف النوع الجديد إلى `NotificationType` enum في `lib/models/notification_model.dart`
2. أضف معالجة التنقل في `NotificationRouter.navigateFromNotification()`
3. أضف أيقونة ولون في `NotificationRouter.getIconForType()` و `getColorForType()`

## استكشاف الأخطاء

### المشكلة: لا تظهر الإشعارات

**الحلول:**
1. تأكد من وجود ملف `google-services.json` في `android/app/`
2. تأكد من أن `applicationId` في `build.gradle.kts` يطابق Package name في Firebase
3. تحقق من الأذونات في إعدادات الجهاز
4. تحقق من Console للأخطاء

### المشكلة: FCM Token غير موجود

**الحلول:**
1. تأكد من تهيئة Firebase قبل استخدام NotificationService
2. تحقق من اتصال الإنترنت
3. تأكد من أن Google Play Services مثبتة على الجهاز

### المشكلة: الإشعارات لا تعمل في الخلفية

**الحلول:**
1. تأكد من أن `firebaseMessagingBackgroundHandler` هو top-level function
2. تحقق من أن التطبيق لديه أذونات الإشعارات
3. على Android، تأكد من عدم إغلاق التطبيق من Battery Optimization

## ملاحظات مهمة

1. **ملف google-services.json**: يجب عدم مشاركة هذا الملف في Git (يجب إضافته إلى `.gitignore`)
2. **FCM Token**: يتم تحديثه تلقائياً عند إعادة تثبيت التطبيق
3. **الأذونات**: يجب طلب أذونات الإشعارات من المستخدم عند أول استخدام
4. **الاختبار**: استخدم Firebase Console لإرسال إشعارات تجريبية

## روابط مفيدة

- [Firebase Console](https://console.firebase.google.com/)
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
