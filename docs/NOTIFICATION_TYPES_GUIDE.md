# دليل أنواع الإشعارات - Loop CRM

## 📋 نظرة عامة

تم إضافة جميع أنواع الإشعارات المطلوبة مع دعم كامل للتخصيص والإعدادات.

## 🔔 أنواع الإشعارات

### 👤 إشعارات العملاء المحتملين (Core Notifications)

#### 📥 عميل محتمل جديد
```dart
await NotificationHelper.notifyNewLead(
  leadId: 123,
  leadName: 'أحمد علي',
  campaignName: 'حملة فيسبوك', // اختياري
);
```

#### ⏱️ بدون متابعة
```dart
await NotificationHelper.notifyLeadNoFollowUp(
  leadId: 123,
  leadName: 'أحمد علي',
  minutes: 30,
);
```

#### 🔁 إعادة تفاعل
```dart
await NotificationHelper.notifyLeadReengaged(
  leadId: 123,
  leadName: 'أحمد علي',
);
```

#### ❌ فشل التواصل
```dart
await NotificationHelper.notifyLeadContactFailed(
  leadId: 123,
  leadName: 'أحمد علي',
  attempts: 3,
);
```

#### 🔄 تغيير الحالة
```dart
await NotificationHelper.notifyLeadStatusChanged(
  leadId: 123,
  leadName: 'أحمد علي',
  newStatus: 'قيد المتابعة',
);
```

#### 🔁 نقل عميل محتمل
```dart
await NotificationHelper.notifyLeadTransferred(
  leadId: 123,
  leadName: 'أحمد علي',
);
```

### 💬 إشعارات واتساب (WhatsApp Automation)

#### 📨 رسالة واردة
```dart
await NotificationHelper.notifyWhatsAppMessageReceived(
  leadId: 123,
  leadName: 'أحمد علي',
  messagePreview: 'مرحباً، أريد معلومات عن...', // اختياري
);
```

#### 📤 إرسال قالب
```dart
await NotificationHelper.notifyWhatsAppTemplateSent(
  leadId: 123,
  leadName: 'أحمد علي',
  templateName: 'رسالة الترحيب',
);
```

#### ⚠️ فشل الإرسال
```dart
await NotificationHelper.notifyWhatsAppSendFailed(
  leadId: 123,
  leadName: 'أحمد علي',
  errorMessage: 'فشل الاتصال بالخادم', // اختياري
);
```

#### ⏳ بانتظار الرد
```dart
await NotificationHelper.notifyWhatsAppWaitingResponse(
  leadId: 123,
  leadName: 'أحمد علي',
  hours: 24,
);
```

### 📢 إشعارات الحملات الإعلانية (Ads Performance)

#### 📊 أداء الحملة
```dart
await NotificationHelper.notifyCampaignPerformance(
  campaignName: 'حملة فيسبوك',
  leadsCount: 100,
);
```

#### ⚠️ انخفاض الأداء
```dart
await NotificationHelper.notifyCampaignLowPerformance(
  campaignName: 'حملة فيسبوك',
  todayLeads: 10,
  yesterdayLeads: 50,
);
```

#### ⛔ إيقاف حملة
```dart
await NotificationHelper.notifyCampaignStopped(
  campaignName: 'حملة فيسبوك',
  reason: 'نفاد الميزانية', // اختياري
);
```

#### 💰 تنبيه الميزانية
```dart
await NotificationHelper.notifyCampaignBudgetAlert(
  campaignName: 'حملة فيسبوك',
  remainingPercentage: 20.0,
);
```

### 📈 إشعارات التقارير (Reports & Insights)

#### 📊 تقرير يومي
```dart
await NotificationHelper.notifyDailyReport(
  leadsCount: 32,
  salesCount: 5,
);
```

#### 📅 تقرير أسبوعي
```dart
await NotificationHelper.notifyWeeklyReport(
  reportUrl: 'https://example.com/report',
);
```

#### 🏆 أفضل موظف
```dart
await NotificationHelper.notifyTopEmployee(
  employeeName: 'محمد أحمد',
  salesCount: 15,
);
```

### 🧾 إشعارات الحساب والنظام (System & Subscription)

#### 🔐 تسجيل دخول
```dart
await NotificationHelper.notifyLoginFromNewDevice(
  deviceName: 'iPhone 14',
  location: 'الرياض، السعودية',
);
```

#### ⚙️ تحديث النظام
```dart
await NotificationHelper.notifySystemUpdate(
  featureName: 'ميزة التقارير المتقدمة',
);
```

#### ❌ فشل الدفع
```dart
await NotificationHelper.notifyPaymentFailed(
  errorMessage: 'البطاقة منتهية الصلاحية', // اختياري
);
```

## ⚙️ إعدادات الإشعارات

### الوصول إلى صفحة الإعدادات

1. اذهب إلى **Settings** (الإعدادات)
2. في تبويب **General** (عام)
3. انقر على **إعدادات الإشعارات**

### الميزات المتاحة

- ✅ **تفعيل/إيقاف جميع الإشعارات**
- ✅ **تخصيص حسب نوع الإشعار** - يمكن تفعيل/إيقاف كل نوع بشكل منفصل
- ✅ **إعدادات وقت الإرسال** - تقييد الإشعارات بوقت محدد
- ✅ **إعادة تعيين الإعدادات** - زر لإعادة الإعدادات للقيم الافتراضية

### مثال: تخصيص إشعارات واتساب فقط

1. افتح **إعدادات الإشعارات**
2. ابحث عن قسم **💬 إشعارات واتساب**
3. فعّل/أوقِف الأنواع المطلوبة

## 🔧 الاستخدام في الكود

### التحقق من الإعدادات قبل الإرسال

النظام يتحقق تلقائياً من الإعدادات قبل إرسال أي إشعار:

```dart
// هذا يتحقق تلقائياً من:
// 1. هل الإشعارات مفعلة بشكل عام؟
// 2. هل هذا النوع من الإشعارات مفعل؟
// 3. هل الوقت الحالي ضمن الوقت المسموح؟

await NotificationHelper.notifyNewLead(
  leadId: 123,
  leadName: 'أحمد علي',
);
```

### إرسال إشعار مباشر (تجاهل الإعدادات)

إذا أردت إرسال إشعار مهم بغض النظر عن الإعدادات:

```dart
await NotificationService().showLocalNotification(
  title: 'إشعار مهم',
  body: 'هذا إشعار مهم جداً',
  payload: NotificationPayload(
    type: NotificationType.general,
    title: 'إشعار مهم',
    body: 'هذا إشعار مهم جداً',
  ),
);
```

## 📱 قنوات الإشعارات (Android)

كل نوع إشعار له قناة منفصلة يمكن تخصيصها في إعدادات Android:

- **leads** - إشعارات العملاء المحتملين
- **whatsapp** - إشعارات واتساب
- **campaigns** - إشعارات الحملات
- **deals** - إشعارات الصفقات
- **tasks** - إشعارات المهام
- **reports** - إشعارات التقارير
- **system** - إشعارات النظام
- **reminders** - التذكيرات
- **general** - الإشعارات العامة

## 🎨 الألوان والأيقونات

كل نوع إشعار له لون وأيقونة مميزة:

- 🔵 **أزرق** - إشعارات جديدة/تعيين
- 🟢 **أخضر** - نجاح/إكمال
- 🟠 **برتقالي** - تحذير/تنبيه
- 🔴 **أحمر** - خطأ/فشل
- 🟣 **بنفسجي** - نقل/تحويل
- 🟡 **أصفر** - تذكير/انتظار

## 📝 ملاحظات

1. **الإعدادات محفوظة محلياً** - يتم حفظها في SharedPreferences
2. **التطبيق التلقائي** - الإعدادات تُطبق تلقائياً على جميع الإشعارات
3. **التنقل التلقائي** - عند النقر على الإشعار، يتم التنقل للشاشة المناسبة
4. **قابل للتوسع** - يمكن إضافة أنواع جديدة بسهولة

## 🔗 روابط مفيدة

- `NOTIFICATIONS_GUIDE.md` - دليل استخدام النظام الكامل
- `FIREBASE_SETUP.md` - دليل إعداد Firebase
- `README_NOTIFICATIONS.md` - ملخص سريع
