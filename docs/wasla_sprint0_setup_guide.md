# 📖 دليل تهيئة واختبار السبرنت 0 (wasla_sprint0_setup_guide.md)

يرشدك هذا الدليل خطوة بخطوة لتهيئة بيئة Supabase وتطبيق تعديلات السبرنت 0 واختبار حماية الـ OTP بنجاح.

---

## 1️⃣ الخطوة الأولى: تطبيق تعديلات قاعدة البيانات (Database Schema)

1. افتح متصفحك واذهب إلى **[Supabase Dashboard](https://supabase.com/dashboard)**.
2. اختر مشروع التطوير التجريبي الخاص بك (**wasla-staging**).
3. من القائمة الجانبية اليسرى، اضغط على **SQL Editor** ثم اضغط على **New query**.
4. انسخ محتويات الملف التالي بالكامل والصقها في المحرر:
   * [wasla-phase0-schema-additions.sql](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/1/wasla-phase0-schema-additions.sql)
5. اضغط على زر **Run** في الزاوية العلوية اليمنى.
6. **التحقق من النجاح:** تأكد من ظهور رسالة نجاح التنفيذ ومن إنشاء الجداول التالية في قاعدة البيانات:
   * جدول `otp_requests` (سجل طلبات التحقق).
   * جدول `legal_acceptances` (سجل الموافقة على الشروط).
   * جدول `account_deletion_requests` (طلبات حذف الحسابات).
   * الأعمدة الجديدة في جدول `ads` (`ai_risk_level`, `ai_review_notes`).
   * الأعمدة الجديدة للحذف الناعم (`deleted_at`) في جداول `users` و `ads` و `reviews`.

---

## 2️⃣ الخطوة الثانية: نشر ودالة Edge Function (`request-otp`)

نظراً لعدم توفر أداة Supabase CLI بشكل عالمي على جهازك، يمكنك استخدام `npx` المدمجة مع Node.js لتنزيل وتشغيل أداة النشر دون الحاجة لتثبيتها يدوياً:

1. افتح الـ Terminal (PowerShell أو CMD) في مسار مجلد المشروع الرئيسي:
   `c:\Users\Maamoun\Downloads\antygravity\وصله`
2. نفّذ الأمر التالي لتسجيل الدخول إلى حسابك في Supabase (سيطلب منك إدخال Access Token تجده في إعدادات حسابك على موقع Supabase):
   ```bash
   npx supabase login
   ```
3. نفّذ الأمر التالي لنشر دالة الـ OTP إلى مشروع الـ Staging الخاص بك:
   ```bash
   npx supabase functions deploy request-otp --project-ref <معرف_مشروعك_الخاص_بـ_Staging>
   ```
   *(ملاحظة: يمكنك إيجاد `<معرف_مشروعك>` في رابط لوحة تحكم مشروعك، على سبيل المثال: `https://supabase.com/project/xxxxxxxxxxxxxxxxxxxx`)*

---

## 3️⃣ الخطوة الثالثة: إعداد الأسرار والبيئات (Secrets)

لكي تتمكن الدالة من الوصول الآمن لبيانات الجداول وإرسال طلبات الـ OTP، يجب وضع المفتاح السري الرئيسي للمشروع كـ Secret داخل بيئة الدالة:

1. نفّذ الأمر التالي من الـ Terminal لوضع المفاتيح (أو قم بإضافتها يدوياً من لوحة التحكم في موقع Supabase تحت تبويب Edge Functions -> request-otp -> Settings -> Secrets):
   ```bash
   npx supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<مفتاح_service_role_الخاص_بمشروعك>" --project-ref <معرف_مشروعك>
   ```

---

## 4️⃣ الخطوة الرابعة: الاختبار الذاتي للدالة (Manual API Testing)

يمكنك اختبار الدالة والتحقق من عمل قيود ومحددات طلب الرمز (Rate Limiting) عبر إرسال طلبات متتالية باستخدام برنامج Postman أو كتابة هذا الأمر في PowerShell/Terminal:

1. **الطلب الأول (يجب أن ينجح):**
   ```bash
   curl -i -X POST https://<معرف_مشروعك>.supabase.co/functions/v1/request-otp \
     -H "Content-Type: application/json" \
     -d '{"phone_number": "01012345678"}'
   ```
   *المتوقع:* الحصول على رد `200 OK` ورسالة `{"success":true,"message":"تم إرسال رمز التحقق بنجاح."}`.

2. **الطلب الثاني مباشرة (يجب أن يُرفض بسبب قيد الـ 3 دقائق):**
   نفّذ نفس الأمر السابق مجدداً في الحال.
   *المتوقع:* الحصول على رد `429 Too Many Requests` ومحتوى:
   `{"code":"RATE_LIMIT_SHORT","message":"يرجى الانتظار 3 دقائق قبل طلب رمز تحقق جديد."}`.

3. **التحقق من لوحة البيانات:**
   اذهب لجدول `otp_requests` في لوحة تحكم Supabase وتأكد من تسجيل العمليات السابقة مع رقم الهاتف وعنوان الـ IP ووقت الطلب بشكل سليم.
