# دليل النشر على Google Play Store

## 📋 المتطلبات الأساسية

قبل البدء في النشر، تأكد من:

1. ✅ حساب مطور Google Play (رسوم لمرة واحدة: $25)
2. ✅ تطبيق Flutter مثبت ومحدث
3. ✅ Java JDK مثبت (لإنشاء Keystore)
4. ✅ Android SDK محدث

## 🔑 الخطوة 1: إنشاء Keystore للتوقيع

### إنشاء ملف Keystore

افتح PowerShell أو Command Prompt وانتقل إلى مجلد `android`:

```powershell
cd C:\Users\ASUS\Desktop\CRM\crm_mobile\android
```

قم بتشغيل الأمر التالي لإنشاء ملف keystore:

```powershell
keytool -genkey -v -keystore crm-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias crm-key
```

**ستحتاج إلى إدخال:**
- **Keystore password**: اختر كلمة مرور قوية (احفظها!)
- **Key password**: عادة نفس كلمة مرور keystore (احفظها!)
- **Your name**: اسمك أو اسم الشركة
- **Organizational Unit**: القسم/الفريق
- **Organization**: اسم الشركة
- **City**: المدينة
- **State**: الولاية/المحافظة
- **Country code**: رمز البلد (مثل: SA, EG, AE)

⚠️ **مهم جداً:** احفظ كلمات المرور وملف keystore في مكان آمن! إذا فقدت ملف keystore، لن تتمكن من تحديث التطبيق على Play Store.

### تحديث ملف key.properties

افتح `android/key.properties` وأضف معلومات keystore:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=crm-key
storeFile=crm-release-key.jks
```

## 📝 الخطوة 2: إعداد ملف .env للإنتاج

**مهم:** قبل بناء التطبيق للإنتاج، تأكد من وجود ملف `.env` في جذر المشروع مع إعدادات الإنتاج:

```env
BASE_URL=https://api.yourdomain.com/api
API_KEY=your_production_api_key_here
```

⚠️ **تحذير أمني:** ملف `.env` سيتم تضمينه في APK. لا تضع مفاتيح API حساسة جداً هنا. استخدم:
- Backend proxy لإخفاء المفاتيح الحقيقية
- OAuth2 أو طرق مصادقة أخرى
- Build flavors لإعدادات مختلفة

## 🏗️ الخطوة 3: بناء App Bundle (AAB)

Google Play Store يتطلب ملف **App Bundle (AAB)** وليس APK.

### بناء App Bundle

انتقل إلى جذر المشروع:

```powershell
cd C:\Users\ASUS\Desktop\CRM\crm_mobile
```

قم بتنظيف المشروع أولاً:

```powershell
flutter clean
```

ثم احصل على التبعيات:

```powershell
flutter pub get
```

الآن قم ببناء App Bundle:

```powershell
flutter build appbundle --release
```

سيتم إنشاء ملف AAB في:
```
build/app/outputs/bundle/release/app-release.aab
```

## 📦 الخطوة 4: إعداد حساب Google Play Console

1. انتقل إلى [Google Play Console](https://play.google.com/console)
2. سجل الدخول بحساب Google
3. إذا لم يكن لديك حساب مطور، ادفع $25 لإنشاء واحد
4. أنشئ تطبيق جديد

## 🎨 الخطوة 5: إعداد صفحة التطبيق على Play Store

### المعلومات المطلوبة:

1. **اسم التطبيق**: LOOP CRM
2. **Application ID**: `com.loopcrm.mobile`
3. **الوصف القصير**: (حتى 80 حرف)
4. **الوصف الكامل**: (حتى 4000 حرف)
5. **الأيقونة**: 512x512 بكسل (PNG)
6. **لقطة شاشة**: 2 على الأقل (PNG أو JPEG)
   - الهاتف: 16:9 أو 9:16
   - الحد الأدنى: 320px
   - الحد الأقصى: 3840px
7. **صورة الميزة**: 1024x500 بكسل (اختياري)
8. **فئة التطبيق**: Business
9. **التصنيف**: CRM/Business Management
10. **الخصوصية**: رابط سياسة الخصوصية (مطلوب)

### الأذونات المطلوبة:

التطبيق يستخدم الأذونات التالية. يجب شرح كل واحدة في Play Console:

- **INTERNET**: للاتصال بالخادم
- **CAMERA**: لالتقاط الصور للملفات الشخصية
- **READ_MEDIA_IMAGES/VIDEO**: لاختيار الصور من المعرض
- **CALL_PHONE**: لإجراء المكالمات
- **POST_NOTIFICATIONS**: لإرسال الإشعارات
- **VIBRATE**: للإشعارات

## 📤 الخطوة 6: رفع App Bundle

1. في Play Console، انتقل إلى **Release** > **Production**
2. انقر على **Create new release**
3. ارفع ملف `app-release.aab`
4. أضف **Release notes** (ملاحظات الإصدار)
5. راجع المعلومات
6. انقر **Review release**

## ✅ الخطوة 7: إكمال المعلومات المطلوبة

قبل النشر، يجب إكمال:

- [ ] **Store listing**: جميع المعلومات الأساسية
- [ ] **Content rating**: تصنيف المحتوى (مطلوب)
- [ ] **Privacy policy**: رابط سياسة الخصوصية (مطلوب)
- [ ] **Target audience**: الجمهور المستهدف
- [ ] **App access**: وصف وصول التطبيق
- [ ] **Data safety**: معلومات أمان البيانات (مطلوب)
- [ ] **Ads**: هل يحتوي على إعلانات؟
- [ ] **In-app purchases**: هل يحتوي على مشتريات داخلية؟

## 🔍 الخطوة 8: مراجعة Google

بعد إرسال التطبيق:

1. **Review process**: قد يستغرق من ساعات إلى أيام
2. **Testing**: اختبر التطبيق على أجهزة مختلفة قبل الإرسال
3. **Internal testing**: استخدم Internal testing track أولاً
4. **Closed testing**: ثم Closed testing مع مجموعة صغيرة
5. **Open testing**: ثم Open testing
6. **Production**: أخيراً Production

## 📊 الخطوة 9: إدارة الإصدارات

### تحديث التطبيق:

1. قم بتحديث رقم الإصدار في `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # versionName+versionCode
   ```

2. قم ببناء App Bundle جديد:
   ```powershell
   flutter build appbundle --release
   ```

3. ارفع الإصدار الجديد في Play Console

⚠️ **مهم:** يجب أن يكون `versionCode` أكبر من الإصدار السابق دائماً.

## 🛡️ الأمان والخصوصية

### ملفات يجب عدم مشاركتها:

- ❌ `android/key.properties`
- ❌ `android/crm-release-key.jks`
- ❌ `.env` (يجب أن يكون في `.gitignore`)

### ملفات يجب نسخها احتياطياً:

- ✅ `crm-release-key.jks` (في مكان آمن!)
- ✅ كلمات مرور keystore (في مدير كلمات مرور آمن)

## 🐛 استكشاف الأخطاء

### خطأ: "Keystore file not found"
- تأكد من وجود `crm-release-key.jks` في مجلد `android`
- تحقق من مسار `storeFile` في `key.properties`

### خطأ: "Wrong password"
- تحقق من كلمات المرور في `key.properties`
- تأكد من عدم وجود مسافات إضافية

### خطأ: "Build failed"
```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

### خطأ: "Application ID already exists"
- Application ID `com.loopcrm.mobile` يجب أن يكون فريداً
- إذا كان مستخدماً، غيّر `applicationId` في `build.gradle.kts`

## 📱 اختبار قبل النشر

### اختبار محلي:

```powershell
# بناء APK للاختبار
flutter build apk --release

# تثبيت على جهاز متصل
flutter install
```

### اختبار App Bundle:

استخدم [bundletool](https://github.com/google/bundletool) لاختبار AAB محلياً:

```powershell
bundletool build-apks --bundle=app-release.aab --output=app.apks --ks=crm-release-key.jks --ks-pass=pass:YOUR_PASSWORD --ks-key-alias=crm-key --key-pass=pass:YOUR_PASSWORD
```

## 📚 موارد إضافية

- [Flutter App Signing](https://docs.flutter.dev/deployment/android#signing-the-app)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Bundle Format](https://developer.android.com/guide/app-bundle)
- [Data Safety Section](https://support.google.com/googleplay/android-developer/answer/10787469)

## ✅ قائمة التحقق النهائية

قبل النشر، تأكد من:

- [ ] Keystore تم إنشاؤه ومحفوظ بشكل آمن
- [ ] `key.properties` محدث بشكل صحيح
- [ ] `.env` يحتوي على إعدادات الإنتاج
- [ ] Application ID فريد (`com.loopcrm.mobile`)
- [ ] رقم الإصدار محدث في `pubspec.yaml`
- [ ] التطبيق تم اختباره على أجهزة مختلفة
- [ ] جميع الأذونات موضحة في Play Console
- [ ] سياسة الخصوصية جاهزة ومرفوعة
- [ ] Data Safety section مكتمل
- [ ] Store listing مكتمل
- [ ] App Bundle تم بناؤه بنجاح
- [ ] تم اختبار App Bundle محلياً

---

**ملاحظة:** هذا الدليل يغطي الخطوات الأساسية. قد تحتاج إلى إجراءات إضافية حسب متطلبات Google Play Store المحددة.
