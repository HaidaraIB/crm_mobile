# 📱 دليل شامل لنشر تطبيق iOS على App Store باستخدام Codemagic

## 📋 المحتويات
1. [المتطلبات الأساسية](#المتطلبات-الأساسية)
2. [إعداد Apple Developer Account](#إعداد-apple-developer-account)
3. [إعداد App Store Connect](#إعداد-apple-store-connect)
4. [إعداد Codemagic](#إعداد-codemagic)
5. [إعداد المشروع](#إعداد-المشروع)
6. [إعداد ملف codemagic.yaml](#إعداد-ملف-codemagicyaml)
7. [إعداد Code Signing](#إعداد-code-signing)
8. [بناء ونشر التطبيق](#بناء-ونشر-التطبيق)
9. [استكشاف الأخطاء](#استكشاف-الأخطاء)

---

## 🎯 المتطلبات الأساسية

قبل البدء، تأكد من توفر:

- ✅ حساب Apple Developer نشط ($99/سنة)
- ✅ حساب Codemagic (يمكنك التسجيل مجاناً)
- ✅ حساب App Store Connect
- ✅ Bundle ID فريد للتطبيق (حالياً: `com.example.crmMobile`)
- ✅ ملف `.env` يحتوي على إعدادات الإنتاج

---

## 🍎 إعداد Apple Developer Account

### الخطوة 1: إنشاء App ID

1. اذهب إلى [Apple Developer Portal](https://developer.apple.com/account/)
2. انتقل إلى **Certificates, Identifiers & Profiles**
3. اضغط على **Identifiers** → **+**
4. اختر **App IDs** → **Continue**
5. اختر **App** → **Continue**
6. أدخل المعلومات التالية:
   - **Description**: CRM Mobile App
   - **Bundle ID**: اختر **Explicit** وأدخل `com.loopcrm.mobile`
   - **Capabilities**: اختر الميزات المطلوبة:
     - ✅ Push Notifications (إذا كنت تستخدم Firebase)
     - ✅ Background Modes
     - ✅ Associated Domains (إذا لزم الأمر)
7. اضغط **Continue** → **Register**

### الخطوة 2: إنشاء App في App Store Connect

1. اذهب إلى [App Store Connect](https://appstoreconnect.apple.com/)
2. اضغط على **My Apps** → **+** → **New App**
3. أدخل المعلومات:
   - **Platform**: iOS
   - **Name**: CRM Mobile (أو الاسم الذي تريده)
   - **Primary Language**: Arabic (أو اللغة الأساسية)
   - **Bundle ID**: اختر `com.loopcrm.mobile`
   - **SKU**: يمكن أن يكون أي معرف فريد (مثل: crm-mobile-ios)
   - **User Access**: Full Access
4. اضغط **Create**

### الخطوة 3: الحصول على App Store Connect API Key

1. في App Store Connect، اذهب إلى **Users and Access**
2. اضغط على **Keys** → **+**
3. أدخل **Name**: Codemagic Integration
4. اختر **Access**: **App Manager** أو **Admin**
5. اضغط **Generate**
6. **احفظ الملف `.p8`** - لن تتمكن من تحميله مرة أخرى!
7. سجل:
   - **Key ID** (مثل: ABC123DEFG)
   - **Issuer ID** (مثل: 12345678-1234-1234-1234-123456789012)

---

## ⚙️ إعداد Codemagic

### الخطوة 1: ربط المستودع

1. اذهب إلى [Codemagic](https://codemagic.io/)
2. اضغط على **Add application**
3. اختر المستودع (GitHub/GitLab/Bitbucket)
4. اختر المستودع `crm_mobile`
5. اضغط **Finish**

### الخطوة 2: إضافة App Store Connect Credentials

1. في صفحة التطبيق، اذهب إلى **Settings** → **Code signing identities**
2. اضغط على **Add credentials**
3. اختر **App Store Connect API key**
4. أدخل:
   - **Issuer ID**: من الخطوة السابقة
   - **Key ID**: من الخطوة السابقة
   - **Private key**: محتوى ملف `.p8` (انسخه كاملاً)
5. اضغط **Save**

### الخطوة 3: إعداد Environment Variables

1. في **Settings** → **Environment variables**
2. أضف المتغيرات التالية:

#### المجموعة: `ios_config`
- `BASE_URL`: رابط API للإنتاج (مثل: `https://api.example.com/api`)
- `API_KEY`: مفتاح API للإنتاج
- `GOOGLE_SERVICE_INFO_PLIST`: محتوى ملف `GoogleService-Info.plist` الكامل (لـ Firebase Push Notifications)

**ملاحظة**: لإعداد Firebase Push Notifications، راجع [دليل إعداد Firebase](./FIREBASE_CODEMAGIC_SETUP.md)

#### المجموعة: `app_store_credentials`
- سيتم إعدادها تلقائياً من App Store Connect API Key

### الخطوة 4: إعداد Code Signing

1. في **Settings** → **Code signing identities**
2. اضغط على **Add credentials**
3. اختر **Automatic** (موصى به) أو **Manual**
4. إذا اخترت **Automatic**:
   - Codemagic سيقوم بإنشاء وإدارة الشهادات تلقائياً
   - تأكد من أن Bundle ID موجود في Apple Developer Portal
5. إذا اخترت **Manual**:
   - ستحتاج إلى رفع:
     - Distribution Certificate (`.p12`)
     - Provisioning Profile (`.mobileprovision`)

---

## 📝 إعداد المشروع

### الخطوة 1: تحديث Bundle ID (اختياري)

إذا كنت تريد تغيير Bundle ID من `com.loopcrm.mobile`:

1. افتح `ios/Runner.xcodeproj` في Xcode
2. اختر **Runner** في Navigator
3. اختر **Runner** تحت **TARGETS**
4. اذهب إلى **Signing & Capabilities**
5. غيّر **Bundle Identifier** إلى القيمة الجديدة
6. احفظ التغييرات

### الخطوة 2: تحديث Info.plist

تأكد من أن `ios/Runner/Info.plist` يحتوي على:

```xml
<key>CFBundleDisplayName</key>
<string>Crm Mobile</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

### الخطوة 3: تحديث الإصدار

في `pubspec.yaml`:

```yaml
version: 1.0.0+2  # قم بزيادة الرقم عند كل نشر
```

- الرقم الأول (`1.0.0`) هو **version name** (يظهر للمستخدمين)
- الرقم الثاني (`+2`) هو **build number** (يجب أن يزيد مع كل بناء)

### الخطوة 4: إعداد Export Options (للمعالجة اليدوية)

إذا كنت تريد التحكم الكامل، أنشئ ملف `ios/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.loopcrm.mobile</key>
        <string>match AppStore com.loopcrm.mobile</string>
    </dict>
</dict>
</plist>
```

---

## 🔧 إعداد ملف codemagic.yaml

الملف موجود في جذر المشروع. تأكد من تحديث القيم التالية:

### 1. تحديث APP_STORE_ID

بعد إنشاء التطبيق في App Store Connect:
1. افتح التطبيق في App Store Connect
2. انسخ **App ID** من العنوان (مثل: `1234567890`)
3. ضعه في `codemagic.yaml`:

```yaml
APP_STORE_ID: "1234567890"  # استبدل برقم التطبيق الفعلي
```

### 2. تحديث البريد الإلكتروني

```yaml
email:
  recipients:
    - your-email@example.com  # استبدل بريدك
```

### 3. تحديث Beta Groups (اختياري)

إذا كنت تستخدم TestFlight:

```yaml
beta_groups:
  - Internal Testers
  - External Testers
```

### 4. تفعيل النشر على App Store

عند الاستعداد للنشر:

```yaml
submit_to_app_store: true  # غيّر من false إلى true
```

---

## 🔐 إعداد Code Signing

### الطريقة الموصى بها: Automatic

Codemagic يدعم **Automatic Code Signing**:

1. في Codemagic، اذهب إلى **Settings** → **Code signing identities**
2. اختر **Automatic**
3. تأكد من:
   - Bundle ID موجود في Apple Developer Portal
   - لديك App Store Connect API Key مضاف
   - لديك صلاحيات كافية في Apple Developer Account

### الطريقة البديلة: Manual

إذا كنت تفضل التحكم الكامل:

#### 1. إنشاء Distribution Certificate

```bash
# على Mac محلي
# 1. افتح Keychain Access
# 2. Certificate Assistant → Request a Certificate From a Certificate Authority
# 3. أدخل بريدك الإلكتروني واسمك
# 4. اختر "Saved to disk"
# 5. ارفع الملف في Apple Developer Portal → Certificates → +
# 6. اختر "Apple Distribution" → Continue
# 7. ارفع CSR → Download
# 8. افتح الملف لتنصيبه في Keychain
# 9. Export Certificate as .p12
```

#### 2. إنشاء Provisioning Profile

1. في Apple Developer Portal → **Profiles** → **+**
2. اختر **App Store** → **Continue**
3. اختر **App ID** → **Continue**
4. اختر **Certificate** → **Continue**
5. أدخل **Profile Name** → **Generate**
6. **Download** الملف (`.mobileprovision`)

#### 3. رفع الملفات في Codemagic

1. في Codemagic → **Settings** → **Code signing identities**
2. اضغط **Add credentials** → **Manual**
3. ارفع:
   - Distribution Certificate (`.p12`)
   - Provisioning Profile (`.mobileprovision`)
   - Certificate Password (إذا كان محمي بكلمة مرور)

---

## 🚀 بناء ونشر التطبيق

### الخطوة 1: تشغيل Build

1. في Codemagic، اذهب إلى **Builds**
2. اضغط **Start new build**
3. اختر:
   - **Workflow**: iOS Workflow
   - **Branch**: `master` (أو الفرع الذي تريد بناءه)
4. اضغط **Start new build**

### الخطوة 2: مراقبة البناء

- ستظهر لك سجلات البناء في الوقت الفعلي
- مدة البناء عادة 10-20 دقيقة
- عند اكتمال البناء بنجاح، سيتم:
  - رفع IPA إلى App Store Connect
  - إرسال نسخة إلى TestFlight (إذا كان مفعلاً)

### الخطوة 3: التحقق في App Store Connect

1. اذهب إلى [App Store Connect](https://appstoreconnect.apple.com/)
2. افتح التطبيق → **TestFlight**
3. ستجد البناء الجديد في **Builds**
4. قد يستغرق المعالجة 10-30 دقيقة

### الخطوة 4: إرسال للمراجعة (Submission)

1. في App Store Connect → **App Store** → **+ Version**
2. اختر **Build** من القائمة
3. املأ المعلومات المطلوبة:
   - **What's New in This Version**: وصف التحديث
   - **Screenshots**: صور للتطبيق (مطلوبة)
   - **Description**: وصف التطبيق
   - **Keywords**: كلمات مفتاحية
   - **Support URL**: رابط الدعم
   - **Privacy Policy URL**: رابط سياسة الخصوصية
   - **Category**: فئة التطبيق
   - **Age Rating**: تصنيف العمر
4. اضغط **Submit for Review**

---

## 🐛 استكشاف الأخطاء

### خطأ: "No profiles for 'com.loopcrm.mobile' were found"

**الحل:**
- تأكد من أن Bundle ID موجود في Apple Developer Portal
- تأكد من وجود Provisioning Profile صالح
- جرب استخدام Automatic Code Signing

### خطأ: "Invalid Bundle Identifier"

**الحل:**
- تأكد من أن Bundle ID في `codemagic.yaml` يطابق Bundle ID في Xcode
- تأكد من أن Bundle ID مسجل في Apple Developer Portal

### خطأ: "Missing API Key" أو "BASE_URL is empty"

**الحل:**
- تأكد من إضافة Environment Variables في Codemagic:
  - `BASE_URL`
  - `API_KEY`
- تأكد من أن المجموعة `ios_config` مضاف في `codemagic.yaml`

### خطأ: "Code signing failed"

**الحل:**
- تحقق من App Store Connect API Key
- تأكد من صلاحيات المفتاح (يجب أن تكون App Manager أو Admin)
- جرب إعادة إنشاء المفتاح

### خطأ: "Build failed" أثناء pod install

**الحل:**
- تأكد من تحديث CocoaPods:
  ```bash
  sudo gem install cocoapods
  pod repo update
  ```
- تحقق من ملف `ios/Podfile`

### خطأ: "Archive failed"

**الحل:**
- تأكد من أن جميع التبعيات محدثة
- تحقق من سجلات Xcode للحصول على تفاصيل أكثر
- تأكد من أن Flutter SDK محدث

---

## 📋 Checklist قبل النشر

- [ ] Bundle ID مسجل في Apple Developer Portal
- [ ] التطبيق موجود في App Store Connect
- [ ] App Store Connect API Key مضاف في Codemagic
- [ ] Environment Variables (`BASE_URL`, `API_KEY`, `GOOGLE_SERVICE_INFO_PLIST`) مضافين
- [ ] Firebase Push Notifications مُعد (راجع [دليل Firebase](./FIREBASE_CODEMAGIC_SETUP.md))
- [ ] Code Signing مضبوط (Automatic أو Manual)
- [ ] `codemagic.yaml` محدث مع `APP_STORE_ID` الصحيح
- [ ] البريد الإلكتروني محدث في `codemagic.yaml`
- [ ] الإصدار محدث في `pubspec.yaml`
- [ ] ملف `.env` يحتوي على إعدادات الإنتاج (سيتم إنشاؤه تلقائياً)
- [ ] جميع الصور والمعلومات جاهزة في App Store Connect
- [ ] تم اختبار التطبيق محلياً

---

## 📚 موارد إضافية

- [Codemagic Documentation](https://docs.codemagic.io/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [إعداد Firebase Push Notifications](./FIREBASE_CODEMAGIC_SETUP.md) - دليل شامل لإعداد Firebase في Codemagic

---

## 💡 نصائح مهمة

1. **ابدأ بـ TestFlight**: اختبر التطبيق على TestFlight قبل النشر على App Store
2. **راقب السجلات**: دائماً راجع سجلات البناء في Codemagic لفهم أي مشاكل
3. **زود Build Number**: تأكد من زيادة Build Number في كل بناء
4. **احفظ المفاتيح**: احفظ App Store Connect API Key في مكان آمن
5. **استخدم Automatic Signing**: أسهل وأكثر أماناً من Manual

---

## 🎉 تهانينا!

بعد اتباع هذا الدليل، ستكون قادراً على:
- ✅ بناء تطبيق iOS تلقائياً باستخدام Codemagic
- ✅ رفعه إلى TestFlight
- ✅ نشره على App Store

إذا واجهت أي مشاكل، راجع قسم [استكشاف الأخطاء](#استكشاف-الأخطاء) أو راجع وثائق Codemagic.

---

**آخر تحديث**: يناير 2026
