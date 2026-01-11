# دليل استخدام نظام الإشعارات

## نظرة عامة

تم تكوين نظام إشعارات Push قابل للتوسع باستخدام Firebase Cloud Messaging (FCM) والإشعارات المحلية. النظام يدعم:

- ✅ إشعارات Push من الخادم (FCM)
- ✅ إشعارات محلية مجدولة
- ✅ تنقل تلقائي بناءً على نوع الإشعار
- ✅ أنواع إشعارات قابلة للتوسع
- ✅ معالجة الإشعارات في الخلفية والأمامية

## البنية

### الملفات الرئيسية

1. **`lib/models/notification_model.dart`**
   - `NotificationType`: enum لأنواع الإشعارات
   - `NotificationPayload`: نموذج بيانات الإشعار

2. **`lib/services/notification_service.dart`**
   - خدمة الإشعارات الرئيسية
   - يدعم FCM والإشعارات المحلية
   - إدارة FCM Token

3. **`lib/services/notification_router.dart`**
   - توجيه المستخدم إلى الشاشة المناسبة
   - أيقونات وألوان للإشعارات

4. **`lib/services/notification_helper.dart`**
   - واجهة بسيطة لإرسال الإشعارات
   - دوال مساعدة لأنواع مختلفة من الإشعارات

## الاستخدام الأساسي

### 1. إرسال إشعار محلي

```dart
import 'package:crm_mobile/services/notification_helper.dart';

// إشعار تعيين عميل
await NotificationHelper.notifyLeadAssigned(
  leadId: 123,
  leadName: 'أحمد علي',
);

// إشعار تحديث عميل
await NotificationHelper.notifyLeadUpdated(
  leadId: 123,
  leadName: 'أحمد علي',
);
```

### 2. جدولة تذكير

```dart
// جدولة تذكير بموعد متابعة عميل
await NotificationHelper.scheduleLeadReminder(
  leadId: 123,
  leadName: 'أحمد علي',
  reminderDate: DateTime.now().add(Duration(days: 1)),
  notes: 'متابعة العرض المقدم',
);
```

### 3. الحصول على FCM Token

```dart
import 'package:crm_mobile/services/notification_service.dart';

final token = await NotificationService().fcmToken;
// إرسال Token إلى الخادم
```

### 4. الاستماع للإشعارات

```dart
NotificationService().notificationStream.listen((payload) {
  print('Received notification: ${payload.title}');
  // معالجة الإشعار
});
```

## إضافة نوع إشعار جديد

### الخطوة 1: إضافة النوع إلى enum

في `lib/models/notification_model.dart`:

```dart
enum NotificationType {
  // ... الأنواع الموجودة
  newFeature, // نوع جديد
}
```

### الخطوة 2: إضافة معالجة التنقل

في `lib/services/notification_router.dart`:

```dart
static Future<void> navigateFromNotification(...) async {
  switch (payload.type) {
    // ... الحالات الموجودة
    case NotificationType.newFeature:
      navigator.pushNamed('/features/new');
      break;
  }
}
```

### الخطوة 3: إضافة أيقونة ولون

```dart
static IconData getIconForType(NotificationType type) {
  switch (type) {
    // ... الحالات الموجودة
    case NotificationType.newFeature:
      return Icons.star;
  }
}

static Color getColorForType(NotificationType type) {
  switch (type) {
    // ... الحالات الموجودة
    case NotificationType.newFeature:
      return Colors.purple;
  }
}
```

### الخطوة 4: إضافة دالة مساعدة (اختياري)

في `lib/services/notification_helper.dart`:

```dart
static Future<void> notifyNewFeature({
  required String featureName,
}) async {
  await _notificationService.showLocalNotification(
    title: 'ميزة جديدة',
    body: 'تم إضافة $featureName',
    payload: NotificationPayload(
      type: NotificationType.newFeature,
      title: 'ميزة جديدة',
      body: 'تم إضافة $featureName',
      data: {'feature_name': featureName},
    ),
  );
}
```

## إرسال إشعارات من الخادم

### هيكل البيانات المطلوب

عند إرسال إشعار من الخادم عبر FCM، يجب أن يحتوي على:

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

### مثال في Python (Django)

```python
from firebase_admin import messaging

def send_lead_assigned_notification(fcm_token, lead_id, lead_name):
    message = messaging.Message(
        notification=messaging.Notification(
            title='تم تعيين عميل جديد',
            body=f'تم تعيين العميل {lead_name} لك',
        ),
        data={
            'type': 'leadAssigned',
            'lead_id': str(lead_id),
            'lead_name': lead_name,
            'title': 'تم تعيين عميل جديد',
            'body': f'تم تعيين العميل {lead_name} لك',
        },
        token=fcm_token,
    )
    
    response = messaging.send(message)
    return response
```

## أنواع الإشعارات المدعومة

### إشعارات العملاء/الليادات
- `leadAssigned` - تم تعيين عميل جديد
- `leadUpdated` - تم تحديث عميل
- `leadStatusChanged` - تغير حالة العميل
- `leadReminder` - تذكير بموعد متابعة عميل

### إشعارات الصفقات
- `dealCreated` - تم إنشاء صفقة جديدة
- `dealUpdated` - تم تحديث صفقة
- `dealClosed` - تم إغلاق صفقة
- `dealReminder` - تذكير بموعد صفقة

### إشعارات المهام
- `taskCreated` - تم إنشاء مهمة جديدة
- `taskCompleted` - تم إكمال مهمة
- `taskReminder` - تذكير بمهمة

### إشعارات النظام
- `systemUpdate` - تحديثات النظام
- `subscriptionExpiring` - انتهاء الاشتراك قريباً
- `subscriptionExpired` - انتهاء الاشتراك

### إشعارات الرسائل
- `newMessage` - رسالة جديدة
- `whatsappMessage` - رسالة واتساب

### إشعارات عامة
- `general` - إشعار عام
- `unknown` - نوع غير معروف

## قنوات الإشعارات (Android)

النظام يستخدم قنوات مختلفة للإشعارات:

- **general** - الإشعارات العامة
- **leads** - إشعارات العملاء
- **deals** - إشعارات الصفقات
- **tasks** - إشعارات المهام
- **reminders** - التذكيرات

يمكن تخصيص كل قناة بشكل منفصل في إعدادات Android.

## الأذونات

النظام يطلب تلقائياً أذونات الإشعارات عند التهيئة. إذا رفض المستخدم الأذونات، يمكن طلبها مرة أخرى:

```dart
final granted = await NotificationService().requestPermissions();
if (granted) {
  print('تم منح الأذونات');
} else {
  print('تم رفض الأذونات');
}
```

## استكشاف الأخطاء

### الإشعارات لا تظهر

1. تحقق من وجود ملف `google-services.json` في `android/app/`
2. تحقق من الأذونات في إعدادات الجهاز
3. تحقق من Console للأخطاء
4. تأكد من تهيئة Firebase قبل استخدام NotificationService

### FCM Token غير موجود

1. تأكد من تهيئة Firebase
2. تحقق من اتصال الإنترنت
3. تأكد من أن Google Play Services مثبتة

### الإشعارات لا تعمل في الخلفية

1. تأكد من أن `firebaseMessagingBackgroundHandler` هو top-level function
2. تحقق من أذونات الإشعارات
3. على Android، تأكد من عدم إغلاق التطبيق من Battery Optimization

## ملاحظات مهمة

1. **FCM Token**: يتم تحديثه تلقائياً عند إعادة تثبيت التطبيق
2. **الإشعارات المحلية**: تعمل حتى بدون اتصال بالإنترنت
3. **التنقل**: يتم التنقل تلقائياً عند النقر على الإشعار
4. **التوسع**: يمكن إضافة أنواع جديدة بسهولة دون تعديل الكود الأساسي

## أمثلة متقدمة

### إرسال إشعار مخصص

```dart
await NotificationService().showLocalNotification(
  title: 'عنوان مخصص',
  body: 'محتوى مخصص',
  payload: NotificationPayload(
    type: NotificationType.general,
    title: 'عنوان مخصص',
    body: 'محتوى مخصص',
    data: {'custom_key': 'custom_value'},
  ),
  channelId: 'general',
  importance: Importance.high,
);
```

### الاشتراك في مواضيع

```dart
// الاشتراك في موضوع
await NotificationService().subscribeToTopic('company_123');

// إلغاء الاشتراك
await NotificationService().unsubscribeFromTopic('company_123');
```

### إلغاء التذكيرات

```dart
// إلغاء تذكير محدد
await NotificationService().cancelReminder(notificationId);

// إلغاء جميع الإشعارات
await NotificationService().cancelAll();
```
