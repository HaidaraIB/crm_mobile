# نظام الإشعارات - ملخص سريع

## ✅ ما تم إنجازه

تم تكوين نظام إشعارات Push قابل للتوسع بالكامل مع:

1. ✅ **Firebase Cloud Messaging (FCM)** - لإشعارات Push من الخادم
2. ✅ **الإشعارات المحلية** - للإشعارات المجدولة والتذكيرات
3. ✅ **نظام أنواع قابل للتوسع** - يمكن إضافة أنواع جديدة بسهولة
4. ✅ **تنقل تلقائي** - يوجه المستخدم للشاشة المناسبة
5. ✅ **معالجة في الخلفية والأمامية** - يعمل في جميع الحالات

## 📁 الملفات المضافة/المعدلة

### ملفات جديدة:
- `lib/models/notification_model.dart` - أنواع الإشعارات ونموذج البيانات
- `lib/services/notification_router.dart` - توجيه الإشعارات
- `lib/services/notification_helper.dart` - دوال مساعدة
- `FIREBASE_SETUP.md` - دليل إعداد Firebase
- `NOTIFICATIONS_GUIDE.md` - دليل استخدام النظام

### ملفات معدلة:
- `pubspec.yaml` - إضافة `firebase_core` و `firebase_messaging`
- `lib/main.dart` - تهيئة Firebase و NotificationService
- `lib/services/notification_service.dart` - تحديث كامل لدعم FCM
- `android/build.gradle.kts` - إضافة Google Services plugin
- `android/app/build.gradle.kts` - تطبيق Google Services plugin
- `.gitignore` - إضافة ملفات Firebase

## 🚀 الخطوات التالية

### 1. إعداد Firebase (مطلوب)

اتبع التعليمات في `FIREBASE_SETUP.md`:

1. إنشاء مشروع Firebase
2. إضافة تطبيق Android
3. تنزيل `google-services.json` ووضعه في `android/app/`
4. (اختياري) إضافة تطبيق iOS

### 2. تثبيت التبعيات

```bash
flutter pub get
```

### 3. بناء التطبيق

```bash
flutter build apk
# أو
flutter run
```

### 4. إرسال FCM Token إلى الخادم

عند تسجيل الدخول، أضف:

```dart
final token = await NotificationService().fcmToken;
// إرسال Token إلى API
await ApiService().updateFCMToken(token);
```

## 📖 الاستخدام

### إرسال إشعار بسيط:

```dart
import 'package:crm_mobile/services/notification_helper.dart';

await NotificationHelper.notifyLeadAssigned(
  leadId: 123,
  leadName: 'أحمد علي',
);
```

### جدولة تذكير:

```dart
await NotificationHelper.scheduleLeadReminder(
  leadId: 123,
  leadName: 'أحمد علي',
  reminderDate: DateTime.now().add(Duration(days: 1)),
);
```

### الحصول على FCM Token:

```dart
final token = await NotificationService().fcmToken;
```

## 🔧 إضافة نوع إشعار جديد

1. أضف النوع إلى `NotificationType` enum
2. أضف معالجة التنقل في `NotificationRouter`
3. أضف أيقونة ولون
4. (اختياري) أضف دالة مساعدة في `NotificationHelper`

راجع `NOTIFICATIONS_GUIDE.md` للتفاصيل.

## 📚 التوثيق

- **FIREBASE_SETUP.md** - دليل إعداد Firebase بالتفصيل
- **NOTIFICATIONS_GUIDE.md** - دليل استخدام النظام الكامل

## ⚠️ ملاحظات مهمة

1. **ملف google-services.json**: يجب عدم مشاركته في Git (تم إضافته إلى `.gitignore`)
2. **FCM Token**: يتم تحديثه تلقائياً
3. **الأذونات**: يتم طلبها تلقائياً عند التهيئة
4. **التوسع**: النظام مصمم ليكون قابلاً للتوسع بسهولة

## 🐛 استكشاف الأخطاء

إذا واجهت مشاكل:

1. تحقق من وجود `google-services.json` في `android/app/`
2. تحقق من Console للأخطاء
3. راجع `FIREBASE_SETUP.md` قسم "استكشاف الأخطاء"
4. تأكد من تهيئة Firebase قبل استخدام NotificationService

## 📞 الدعم

للحصول على مساعدة إضافية، راجع:
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
