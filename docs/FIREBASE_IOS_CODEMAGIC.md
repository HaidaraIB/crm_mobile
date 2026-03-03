# Firebase iOS + Codemagic — التحقق والإعداد

## 0. Xcode Capabilities بدون Mac (Push Notifications)

خطوة "تفعيل Push Notifications في Xcode → Signing & Capabilities" التي تراها في الفيديوه تعادل شيئين في المشروع:

1. **ملف الصلاحيات (Entitlements)**  
   الملف `ios/Runner/Runner.entitlements` يجب أن يحتوي على:
   - `aps-environment` = `production` (للبناء Release/TestFlight) أو `development` (للبناء Debug).  
   في هذا المشروع مضبوط على `production` لأن التوزيع عبر TestFlight.

2. **ربط الملف بمشروع Xcode**  
   في `ios/Runner.xcodeproj/project.pbxproj` يجب أن يكون للهدف Runner الإعداد:
   - `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`  
   في إعدادات البناء **Debug** و **Release** و **Profile**.

بدون هذا الربط، الملف الموجود على القرص **لا يُضمَّن** في التطبيق عند البناء، فلا تحصل على صلاحية Push ولا يُولَّد توكن FCM.

**لا تحتاج Mac أو Xcode محلياً:** التعديلات أعلاه تُجرى على الملفات النصية (`.entitlements` و `project.pbxproj`) وتُرفع إلى الـ repo. عند البناء على Codemagic (الذي يستخدم Xcode على سيرفراتهم)، Xcode يقرأ هذه الملفات ويطبّق الصلاحيات تلقائياً.

ملخص ما هو مضبوط في هذا المشروع:
- `Runner.entitlements`: فيه `aps-environment` = `production`.
- `Info.plist`: فيه `UIBackgroundModes` → `remote-notification`.
- `project.pbxproj`: `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` لجميع إعدادات Runner.

---

## 1. التأكد من إعداد Firebase Console (لتوليد التوكنات على iOS)

### أ. تطبيق iOS مضاف في Firebase
1. ادخل إلى [Firebase Console](https://console.firebase.google.com) → اختر المشروع **crm-mobile-409dc**.
2. من **Project settings** (أيقونة الترس) → **Your apps**.
3. يجب أن ترى تطبيق **iOS** مع:
   - **Bundle ID**: `com.loopcrm.mobile` (مطابق تماماً لـ Xcode و Codemagic).
   - **App ID**: يبدأ بـ `1:820359795982:ios:...` (مثل: `1:820359795982:ios:d4aa0870fe4896fe44b35f`).

إذا لم يكن التطبيق مضافاً، أضف **Add app** → **iOS** وأدخل Bundle ID: `com.loopcrm.mobile`، ثم حمّل **GoogleService-Info.plist** وضعه في المشروع أو استخدم محتواه في Codemagic (انظر القسم 3).

### ب. مفتاح APNs مرفوع في Firebase (ضروري لـ FCM على iOS)
بدون مفتاح APNs لا تستطيع Firebase إصدار توكنات FCM لأجهزة iOS.

1. في Firebase Console → **Project settings** → تبويب **Cloud Messaging**.
2. في قسم **Apple app configuration**:
   - إما **APNs Authentication Key** (ملف .p8 من Apple Developer)، أو
   - **APNs Certificates** (شهادة .p12).
3. إذا كان الحقل فارغاً:
   - من [Apple Developer](https://developer.apple.com/account/resources/authkeys/list) أنشئ **Key** مع تفعيل **Apple Push Notifications service (APNs)**.
   - حمّل الملف **.p8** واحتفظ بـ **Key ID** و **Team ID** و **Bundle ID**.
   - في Firebase → **Cloud Messaging** → **Upload** وارفع المفتاح .p8 وأدخل Key ID و Team ID و Bundle ID `com.loopcrm.mobile`.

عند اكتمال ذلك، Firebase يكون قادراً على توليد توكنات FCM لـ iOS.

---

## 2. كيف تعرف أن معلومات التطبيق (Firebase App Info) مضبوطة بشكل صحيح؟

### في المشروع المحلي
- وجود الملف **`ios/Runner/GoogleService-Info.plist`** مع:
  - `BUNDLE_ID` = `com.loopcrm.mobile`
  - `GOOGLE_APP_ID` = `1:820359795982:ios:...`
  - `PROJECT_ID` = `crm-mobile-409dc`
  - `GCM_SENDER_ID` أو ما يكافئه
- في Xcode: **Bundle Identifier** للـ Runner = `com.loopcrm.mobile` (هذا مضبوط في المشروع الحالي).

### عند البناء عبر Codemagic
- في الـ build log يجب أن ترى:
  - `✅ Wrote GoogleService-Info.plist from GOOGLE_SERVICE_INFO_PLIST` أو
  - `✅ GoogleService-Info.plist validated (BUNDLE_ID and GOOGLE_APP_ID present)`  
  إذا ظهر `❌ No valid GoogleService-Info.plist` أو `❌ GoogleService-Info.plist invalid` فالبناء يفشل عمداً حتى لا تخرج نسخة بدون Firebase.

### على الجهاز (توليد التوكن)
- بعد تثبيت النسخة من TestFlight/App Store:
  - سجّل الدخول وافتح التطبيق واقبل الإشعارات.
  - إذا كان كل شيء مضبوطاً ستجد في قاعدة البيانات أن حقل **fcm_token** لهذا المستخدم لم يعد `NULL` (التطبيق يرسل التوكن للخادم عند الحصول عليه وعند الاستئناف).
- في التطبيق (لو أضفت طباعة في التطبيق): رسالة مثل `✓ FCM Token: ...` تعني أن Firebase ولّد التوكن بنجاح.

---

## 3. إعداد Codemagic: متغير GOOGLE_SERVICE_INFO_PLIST

عند النشر عبر Codemagic يجب أن يكون ملف **GoogleService-Info.plist** متوفراً أثناء البناء. الطريقتان المعتادتان:

### الطريقة 1: متغير بيئة يحتوي محتوى الملف (مستحسن لـ CI)
1. في Codemagic: **Teams** → اختَر الفريق → **Environment variables** (أو من الـ workflow: **Environment variables**).
2. أنشئ **Group** (مثل `ios_config`) وأضف متغيراً:
   - **Name**: `GOOGLE_SERVICE_INFO_PLIST`
   - **Value**: المحتوى **الكامل** لملف `GoogleService-Info.plist` (كل الـ XML من `<?xml` حتى `</plist>`).
3. عند نسخ المحتوى من الملف تأكد أنك لا تحذف أي سطر وأن الـ Bundle ID و GOOGLE_APP_ID صحيحان.

ملاحظة: إذا كان المحتوى متعدد الأسطر، في واجهة Codemagic عادة يكون هناك حقل كبير للنص (أو تحميل من ملف). استخدم **Secure** فقط إذا كان المفتاح سرياً؛ المحتوى هنا ليس سرياً بالمعنى الأمني لكن يمكن وضعه كـ **Secure** لتفادي العرض في الـ log.

### الطريقة 2: الاعتماد على الملف في المستودع
- إذا كان **GoogleService-Info.plist** موجوداً في المستودع داخل `ios/Runner/` ولا تريد استخدام متغير:
  - اترك **GOOGLE_SERVICE_INFO_PLIST** فارغاً في Codemagic.
  - السكربت الحالي سيتحقق من وجود الملف وصحته (BUNDLE_ID و GOOGLE_APP_ID). إذا كان الملف صحيحاً فالبناء ينجح بدون تعبئة المتغير.

تحذير: إذا وضعت الملف في الـ repo فتأكد من عدم إضافة معلومات حساسة إضافية. عادة هذا الملف لا يعتبر سرياً لكن سياسات بعض الفرق تمنع وضعه في الـ repo؛ في تلك الحالة استخدم الطريقة 1.

---

## 4. ملخص التحقق السريع

| ماذا تتحقق؟ | أين؟ |
|-------------|------|
| تطبيق iOS مضاف و Bundle ID = com.loopcrm.mobile | Firebase Console → Project settings → Your apps |
| مفتاح APNs مرفوع (APNs Key أو Certificate) | Firebase Console → Project settings → Cloud Messaging → Apple app configuration |
| GoogleService-Info.plist موجود وصحيح في البناء | Codemagic build log: "GoogleService-Info.plist validated" |
| توكن FCM يُولَّد على الجهاز | بعد تثبيت من TestFlight: فتح التطبيق وتسجيل الدخول ثم التحقق من حقل fcm_token في قاعدة البيانات |

إذا اكتملت النقاط أعلاه، فإن Firebase يكون مضبوطاً وقادراً على توليد التوكنات لـ iOS، والنشر عبر Codemagic يستخدم تكوين التطبيق الصحيح.

---

## 5. بروفايل التوقيع (Provisioning Profile) و FCM على iOS

إذا كانت الإشعارات تعمل عند التشغيل المحلي على جهازك لكن **لا تعمل على نسخة مبنية من Codemagic** (أو TestFlight)، فغالباً السبب أن البروفايل المستخدم في البناء **لا يحتوي على صلاحية Push Notifications**.

مرجع: [Flutter FCM notifications not arriving on Codemagic iOS build (Stack Overflow)](https://stackoverflow.com/questions/66084863/flutter-fcm-notifications-not-arriving-on-codemagic-ios-build)

### خطأ البناء: "doesn't include the Push Notifications capability" / "doesn't include the aps-environment entitlement"
إذا ظهر هذا الخطأ فمعناه أن البروفايل الذي يُستخدم (مثل "loop crm ios app_store 1769965601") **لا يحتوي** على صلاحية Push. الإصلاح من Apple Developer:

1. **Identifiers** → **App IDs** → اختر `com.loopcrm.mobile` → تأكد أن **Push Notifications** مضاف في Capabilities (فعّله إن لم يكن).
2. **Profiles** → ابحث عن البروفايل الذي يظهر في الخطأ (مثل "loop crm ios app_store 1769965601"):
   - إما **احذفه** وأنشئ **Distribution** جديداً لنفس الـ App ID (بعد تفعيل Push في الخطوة 1)، ثم في Codemagic أعد ربط الحساب أو حدّث الـ profiles.
   - أو عدّل الـ App ID أولاً (Push On)، ثم من صفحة البروفايل اختر **Edit** → **Generate** لإنشاء نسخة جديدة من البروفايل تحتوي Push، ونزّلها/فعّلها في Codemagic.
3. السكربت في **codemagic.yaml** يختار فقط بروفايلات تحتوي على **aps-environment** (Push). إن وُجد بروفايل اسمه **"loop"** وفيه Push سيُفضَّل؛ وإلا يُستخدم أي بروفايل لـ `com.loopcrm.mobile` وفيه Push. إن لم يوجد أي بروفايل مع Push، البناء يفشل برسالة واضحة.

### ما يجب التحقق منه
1. **في Apple Developer Portal** → **Profiles**:
   - البروفايل المستخدم للتوزيع (مثل **"loop"** لـ `com.loopcrm.mobile`) يجب أن يكون **Active** وأن تكون **Push Notifications** ضمن **Enabled Capabilities**.
2. إذا أضفت FCM **بعد** أن كان Codemagic يوقّع تلقائياً، قد يكون البروفايل الذي أنشأه Codemagic سابقاً **بدون** Push:
   - احذف ذلك البروفايل من Apple Developer حتى ينشئ Codemagic (أو تربط يدوياً) بروفايلاً جديداً بعد تفعيل Push في Xcode/App ID.
3. في هذا المشروع، السكربت في **codemagic.yaml** يختار فقط بروفايلات تحتوي **aps-environment**، ويفضّل الذي اسمه **"loop"**.

### بيئة APNs (Sandbox vs Production)
- بناء **Debug** يتصل بـ **Sandbox**؛ بناء **Release** (مثل TestFlight) يتصل بـ **Production**.
- في Firebase → Cloud Messaging → Apple app configuration يجب رفع مفتاح APNs لكل من **Development** و **Production** (أو استخدام مفتاح .p8 واحد يعمل للاثنين).
