# CRM Mobile App

تطبيق CRM للهواتف المحمولة مبني باستخدام Flutter.

## المميزات

- ✅ إدارة الحالة باستخدام BLoC
- ✅ تخزين البيانات باستخدام Shared Preferences
- ✅ دعم اللغتين العربية والإنجليزية
- ✅ دعم الوضع الفاتح والداكن
- ✅ إشعارات وتذكيرات للعملاء
- ✅ تصميم حديث ومتجاوب

## البنية الأساسية

```
lib/
├── core/
│   ├── bloc/          # BLoC لإدارة الحالة
│   ├── constants/     # الثوابت
│   ├── localization/ # الترجمة
│   └── theme/         # الثيمات
├── models/            # نماذج البيانات
├── screens/           # الشاشات
├── services/          # الخدمات (API, Notifications)
└── widgets/           # الويدجتات القابلة لإعادة الاستخدام
```

## التبعيات الرئيسية

- `flutter_bloc`: إدارة الحالة
- `shared_preferences`: تخزين البيانات محلياً
- `http`: طلبات API
- `flutter_local_notifications`: الإشعارات والتذكيرات
- `intl`: الترجمة والتنسيق

## التشغيل

1. تثبيت التبعيات:
```bash
flutter pub get
```

2. تشغيل التطبيق:
```bash
flutter run
```

## ملاحظات

- تأكد من تحديث `BASE_URL` في `lib/core/constants/app_constants.dart` ليشير إلى عنوان API الخاص بك
- قم بتكوين الإشعارات في ملفات Android/iOS حسب الحاجة
