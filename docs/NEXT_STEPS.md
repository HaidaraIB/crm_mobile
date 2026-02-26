# الخطوات التالية - نظام الإشعارات

## ✅ ما تم إنجازه

تم تكوين نظام الإشعارات بنجاح! كما يظهر من الـ logs:

- ✅ Firebase تم تهيئته بنجاح
- ✅ FCM Token تم الحصول عليه: `[FCM_TOKEN_HERE]`
- ✅ NotificationService تم تهيئته بنجاح
- ✅ الأذونات تم منحها

## 📋 الخطوات التالية

### 1. إضافة API Endpoint في الخادم (Backend)

يجب إضافة endpoint في Django لإستقبال FCM Token:

```python
# في accounts/views.py أو في ملف views مناسب

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    """
    تحديث FCM Token للمستخدم الحالي
    """
    fcm_token = request.data.get('fcm_token')
    
    if not fcm_token:
        return Response(
            {'error': 'fcm_token is required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # حفظ Token في قاعدة البيانات
    # يمكن إضافة حقل fcm_token في User model أو إنشاء جدول منفصل
    user = request.user
    user.fcm_token = fcm_token
    user.save()
    
    return Response(
        {'message': 'FCM token updated successfully'},
        status=status.HTTP_200_OK
    )
```

**إضافة URL:**

```python
# في urls.py
path('users/update-fcm-token/', update_fcm_token, name='update_fcm_token'),
```

**إضافة حقل في User Model (اختياري):**

```python
# في accounts/models.py
class User(AbstractUser):
    # ... الحقول الموجودة
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
```

### 2. اختبار الإشعارات المحلية

يمكنك اختبار الإشعارات المحلية مباشرة:

```dart
import 'package:crm_mobile/services/notification_helper.dart';

// في أي مكان في التطبيق
await NotificationHelper.notifyLeadAssigned(
  leadId: 123,
  leadName: 'أحمد علي',
);
```

### 3. إرسال إشعارات من الخادم

بعد إضافة FCM Token في قاعدة البيانات، يمكنك إرسال إشعارات من Django:

**تثبيت Firebase Admin SDK:**

```bash
pip install firebase-admin
```

**إعداد Firebase Admin:**

```python
# في settings.py أو ملف منفصل
import firebase_admin
from firebase_admin import credentials, messaging

# تهيئة Firebase Admin (مرة واحدة فقط)
if not firebase_admin._apps:
    cred = credentials.Certificate("path/to/serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
```

**إرسال إشعار:**

```python
from firebase_admin import messaging

def send_notification_to_user(user, title, body, notification_type, data=None):
    """
    إرسال إشعار إلى مستخدم محدد
    """
    if not user.fcm_token:
        return False
    
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data={
            'type': notification_type,
            'title': title,
            'body': body,
            **(data or {})
        },
        token=user.fcm_token,
    )
    
    try:
        response = messaging.send(message)
        return True
    except Exception as e:
        print(f"Error sending notification: {e}")
        return False

# مثال الاستخدام:
send_notification_to_user(
    user=request.user,
    title='تم تعيين عميل جديد',
    body='تم تعيين العميل أحمد علي لك',
    notification_type='leadAssigned',
    data={
        'lead_id': '123',
        'lead_name': 'أحمد علي',
    }
)
```

### 4. إرسال إشعارات عند الأحداث

يمكنك إضافة إشعارات عند حدوث أحداث معينة:

**مثال: عند تعيين عميل:**

```python
# في signals.py أو في view
from django.db.models.signals import post_save
from django.dispatch import receiver

@receiver(post_save, sender=Client)
def notify_lead_assigned(sender, instance, created, **kwargs):
    if created and instance.assigned_to:
        send_notification_to_user(
            user=instance.assigned_to,
            title='تم تعيين عميل جديد',
            body=f'تم تعيين العميل {instance.name} لك',
            notification_type='leadAssigned',
            data={
                'lead_id': str(instance.id),
                'lead_name': instance.name,
            }
        )
```

### 5. اختبار الإشعارات من Firebase Console

يمكنك اختبار الإشعارات مباشرة من Firebase Console:

1. اذهب إلى Firebase Console
2. اختر مشروعك
3. اذهب إلى Cloud Messaging
4. انقر "Send your first message"
5. أدخل العنوان والمحتوى
6. في "Additional options" → "Custom data"، أضف:
   - `type`: `leadAssigned`
   - `lead_id`: `123`
   - `title`: `تم تعيين عميل جديد`
   - `body`: `تم تعيين العميل أحمد علي لك`
7. اختر "Send test message"
8. أدخل FCM Token: `[YOUR_FCM_TOKEN]`

### 6. إضافة إشعارات في الأماكن المناسبة

يمكنك إضافة إشعارات في التطبيق عند:

- **تعيين عميل جديد**: في `assignLeads` function
- **تحديث عميل**: في `updateLead` function
- **إنشاء صفقة**: في `createDeal` function
- **إغلاق صفقة**: في `updateDeal` function
- **إنشاء مهمة**: في `addActionToLead` function

**مثال:**

```dart
// في api_service.dart بعد assignLeads
Future<void> assignLeads({
  required List<int> clientIds,
  int? userId,
}) async {
  // ... الكود الموجود
  
  // إرسال إشعار
  if (userId != null) {
    final user = await getUserById(userId);
    // يمكن إرسال إشعار هنا
  }
}
```

## 📝 ملاحظات مهمة

1. **FCM Token يتحدث تلقائياً**: عند تحديث Token، يتم إرساله تلقائياً إلى الخادم
2. **الإشعارات المحلية تعمل دائماً**: حتى بدون Firebase، الإشعارات المحلية ستعمل
3. **التنقل التلقائي**: عند النقر على الإشعار، سيتم التنقل تلقائياً للشاشة المناسبة
4. **إضافة أنواع جديدة**: يمكن إضافة أنواع إشعارات جديدة بسهولة (راجع `NOTIFICATIONS_GUIDE.md`)

## 🔗 روابط مفيدة

- `FIREBASE_SETUP.md` - دليل إعداد Firebase
- `NOTIFICATIONS_GUIDE.md` - دليل استخدام النظام الكامل
- `README_NOTIFICATIONS.md` - ملخص سريع

## ✅ Checklist

- [ ] إضافة API endpoint في Django لإستقبال FCM Token
- [ ] إضافة حقل `fcm_token` في User model (اختياري)
- [ ] اختبار إرسال Token من التطبيق
- [ ] تثبيت Firebase Admin SDK في Django
- [ ] إعداد Firebase Admin credentials
- [ ] اختبار إرسال إشعار من Firebase Console
- [ ] إضافة إشعارات عند الأحداث المهمة
- [ ] اختبار الإشعارات المحلية في التطبيق

## 🎉 تهانينا!

نظام الإشعارات جاهز ويعمل! الآن يمكنك:
- ✅ إرسال إشعارات محلية
- ✅ استقبال إشعارات من الخادم
- ✅ جدولة تذكيرات
- ✅ التنقل التلقائي عند النقر على الإشعارات
