# 📅 خطة المهام وجدول التطوير (Sprints) — منصة "وصلة" (Wasla Sprint & Task Plan)

تقسم هذه الخطة العمل البرمجي المتبقي لتطوير منصة "وصلة" (Wasla) إلى **5 سبرينتات (Sprints)**، مدة كل سبرينت **أسبوعان**، للوصول بالتطبيق من حالته الحالية إلى الإصدار الأول الجاهز للإطلاق (MVP).

---

## 🏃‍♂️ نظرة عامة على مراحل التطوير

```mermaid
gantt
    title جدول تطوير منصة وصلة (10 أسابيع)
    dateFormat  YYYY-MM-DD
    section برمجة الواجهات والتكامل
    السبرينت 1: التوثيق الأمني KYC وتفاصيل المعلن  :active, des1, 2026-06-22, 14d
    السبرينت 2: معالج نشر الإعلانات الديناميكي   : des2, after des1, 14d
    السبرينت 3: بوابة المدفوعات والتعزيز (Boost)  : des3, after des2, 14d
    السبرينت 4: الإشعارات وتحديث الإعدادات والبحث : des4, after des3, 14d
    السبرينت 5: لوحة المشرفين والاختبارات الشاملة : des5, after des4, 14d
```

---

## 📋 تفاصيل السبرينتات وتوزيع المهام (Sprint Backlog)

---

### 🏃‍♂️ السبرينت 1: التوثيق الأمني (KYC) وتفاصيل المعلن
* **التركيز:** إنهاء نظام التوثيق بالبطاقة القومية وإتاحة تصفح حسابات المعلنين العامة.
* **مهام الجوال (Flutter Tasks):**
  * [ ] بناء شاشة التوثيق [verification_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/profile/screens/verification_screen.dart) وتكاملها مع الكاميرا الحية لمنع اختيار صور من الاستوديو.
  * [ ] بناء شاشة معرض الصور التفاعلي [photo_viewer_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/ads/screens/photo_viewer_screen.dart) بدعم التكبير والسحب.
  * [ ] بناء شاشة ملف المعلن العام [seller_profile_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/ads/screens/seller_profile_screen.dart) لعرض تقييمات المعلن وإعلاناته الأخرى.
* **مهام السيرفر وقاعدة البيانات (Backend Tasks):**
  * [ ] تهيئة الـ Private Bucket (`documents`) لرفع صور الهوية وتطبيق قواعد الوصول الأمنية.
  * [ ] برمجة Edge Function لمطابقة صورة السيلفي بصورة بطاقة الرقم القومي وحساب درجة التشابه.

---

### 🏃‍♂️ السبرينت 2: معالج نشر الإعلانات الديناميكي (Post Ad Wizard)
* **التركيز:** إتاحة إمكانية نشر الإعلانات وتطويع الحقول حسب القسم المختار.
* **مهام الجوال (Flutter Tasks):**
  * [ ] بناء فورم التفاصيل [ad_form_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/post_ad/screens/ad_form_screen.dart) وتصميم الحقول الديناميكية لتظهر حسب الفئة.
  * [ ] بناء شاشة رفع وترتيب الصور وتحديد الصورة الرئيسية [add_photos_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/post_ad/screens/add_photos_screen.dart).
  * [ ] بناء شاشة تحديد السعر ونوعه وخيارات الاتصال بالإضافة لتحديد الحي الدقيق على خريطة Google Maps [location_price_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/post_ad/screens/location_price_screen.dart).
  * [ ] بناء شاشات المعاينة والنجاح [ad_preview_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/post_ad/screens/ad_preview_screen.dart) و [ad_success_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/post_ad/screens/ad_success_screen.dart).
* **مهام السيرفر وقاعدة البيانات (Backend Tasks):**
  * [ ] تفعيل قواعد الـ RLS لجداول الإعلانات والوسائط وقيم الحقول الديناميكية (`ad_fields`).

---

### 🏃‍♂️ السبرينت 3: بوابة المدفوعات والتعزيز (Boost & Subscriptions)
* **التركيز:** دمج بوابة Paymob المالية وتفعيل التعزيز والاشتراكات.
* **مهام الجوال (Flutter Tasks):**
  * [ ] بناء شاشة ترقية وتعزيز الإعلانات [boost_ad_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/profile/screens/boost_ad_screen.dart).
  * [ ] بناء شاشة باقات الاشتراكات التجارية [subscription_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/profile/screens/subscription_screen.dart).
  * [ ] دمج الـ WebView بداخل شاشة الدفع الآمن [PaymentWebViewScreen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/payment/screens/payment_webview_screen.dart).
* **مهام السيرفر وقاعدة البيانات (Backend Tasks):**
  * [ ] بناء الـ Edge Function (`create-payment`) للتواصل مع API Paymob وتوليد الـ Payment Key.
  * [ ] بناء الـ Webhook الخاص باستقبال تأكيدات الدفع (`payment-webhook`) والتحقق من الـ HMAC Signature لتحديث باقات ورصيد المعلن تلقائياً.

---

### 🏃‍♂️ السبرينت 4: الإشعارات، البحث، وتحديث الإعدادات
* **التركيز:** تفعيل التنبيهات الفورية وتحسين محرك البحث وتفاصيل المستخدم.
* **مهام الجوال (Flutter Tasks):**
  * [ ] بناء مركز الإشعارات وتحديد الإشعارات كمقروءة [notifications_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/notifications/screens/notifications_screen.dart).
  * [ ] تكامل Firebase Messaging لالتقاط الإشعارات في الخلفية وتحديث بادج التطبيق.
  * [ ] بناء شاشة الإعدادات العامة وخيار حذف الحساب نهائياً [settings_screen.dart](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/profile/screens/settings_screen.dart).
* **مهام السيرفر وقاعدة البيانات (Backend Tasks):**
  * [ ] إعداد Triggers قاعدة البيانات لإرسال الإشعارات التلقائية (مثال: عند نشر إعلان يطابق الـ Watchlist لمستخدم، يتم تفعيل Edge Function لإرسال إشعار FCM فوري).
  * [ ] تحسين الفهرسة للغة العربية في محرك البحث.

---

### 🏃‍♂️ السبرينت 5: لوحة تحكم المشرفين والاختبارات الشاملة (Admin & QA)
* **التركيز:** إتاحة واجهات المراجعة للمشرفين، وإجراء الفحوصات النهائية للنشر.
* **مهام الجوال (Flutter Tasks / Next.js Admin Tasks):**
  * [ ] بناء شاشات لوحة تحكم المشرف [ModeratorDashboard](file:///c:/Users/Maamoun/Downloads/antygravity/وصله/frontend/mobile/wasla/lib/features/admin/screens/moderator_dashboard.dart) لمراجعة الإعلانات المعلقة والبلاغات وحظر الحسابات المشبوهة.
* **مهام الجودة والاختبارات (QA Tasks):**
  * [ ] تنفيذ اختبارات الوحدات (Unit Tests) للـ Providers والـ Models وتأكيد تخطيها نسبة 70%.
  * [ ] محاكاة الشبكات الضعيفة واختبار توافقية الشاشات الـ RTL.
  * [ ] تجربة النظام الكامل (End-to-End Test) من تسجيل هاتف جديد وحتى إتمام عملية بيع إعلان ممول.
