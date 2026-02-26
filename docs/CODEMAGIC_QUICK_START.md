# 🚀 دليل سريع: نشر iOS على App Store باستخدام Codemagic

## ⚡ البدء السريع (5 خطوات)

### 1️⃣ إعداد Apple Developer Account
- ✅ سجل في [Apple Developer](https://developer.apple.com/) ($99/سنة)
- ✅ أنشئ App ID: `com.loopcrm.mobile`
- ✅ أنشئ التطبيق في [App Store Connect](https://appstoreconnect.apple.com/)

### 2️⃣ الحصول على App Store Connect API Key
1. App Store Connect → **Users and Access** → **Keys** → **+**
2. اسم: `Codemagic Integration`
3. صلاحيات: **App Manager** أو **Admin**
4. **احفظ ملف `.p8`** و Key ID و Issuer ID

### 3️⃣ إعداد Codemagic
1. سجل في [Codemagic](https://codemagic.io/)
2. **Add application** → اختر مستودع `crm_mobile`
3. **Settings** → **Code signing identities**:
   - اضغط **Add credentials** → **App Store Connect API key**
   - أدخل Issuer ID, Key ID, Private key (من ملف .p8)
4. **Settings** → **Environment variables**:
   - أضف `BASE_URL` و `API_KEY` في مجموعة `ios_config`

### 4️⃣ تحديث codemagic.yaml
```yaml
# في codemagic.yaml، حدّث:
APP_STORE_ID: "1234567890"  # من App Store Connect
email:
  recipients:
    - your-email@example.com  # بريدك
```

### 5️⃣ تشغيل البناء
1. في Codemagic → **Builds** → **Start new build**
2. اختر **iOS Workflow** و الفرع `master`
3. اضغط **Start new build**
4. انتظر 10-20 دقيقة
5. ✅ سيتم رفع IPA تلقائياً إلى TestFlight!

---

## 📝 Checklist سريع

- [ ] Apple Developer Account نشط
- [ ] App ID موجود: `com.loopcrm.mobile`
- [ ] التطبيق موجود في App Store Connect
- [ ] App Store Connect API Key مضاف في Codemagic
- [ ] Environment Variables (`BASE_URL`, `API_KEY`) موجودة
- [ ] `codemagic.yaml` محدث
- [ ] تم رفع الكود إلى Git

---

## 🔗 روابط مهمة

- [Codemagic Dashboard](https://codemagic.io/apps)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Apple Developer Portal](https://developer.apple.com/account/)

---

## 📖 للمزيد من التفاصيل

راجع الدليل الشامل: [CODEMAGIC_IOS_GUIDE.md](./CODEMAGIC_IOS_GUIDE.md)

---

**ملاحظة**: تأكد من قراءة الدليل الشامل للحصول على تفاصيل كاملة حول استكشاف الأخطاء والإعدادات المتقدمة.
