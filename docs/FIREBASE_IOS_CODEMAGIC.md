# Firebase iOS + Codemagic — التحقق والإعداد

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
