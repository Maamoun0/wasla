# قائمة ما قبل الإطلاق

كل حاجة لسه واقفة قبل ما وصلة تتنشر، مقسّمة حسب المسؤول. قدّام كل بند الأمر أو الاختبار اللي يثبت إنه خلص. البند مايتعلّمش ✅ غير لما الدليل ده يتشغّل وينجح.

آخر تحديث: 2026-11-01 (فرع `fix/audit`). التفاصيل في `docs/audit/AUDIT_REPORT.md`، وخطوات الإنتاج في `docs/wasla_production_migration_plan.md`، وربط الخدمات في `docs/INTEGRATION_CHECKLIST.md`.

**المسؤولين:**
- **صاحب المشروع:** قرارات، وحسابات، ومفاتيح، وفلوس.
- **المطوّر (Claude):** كود، وmigrations، واختبارات.
- **مستشار قانوني.**
- **مزوّد الخدمة:** حاجات بتحصل في حساب عند طرف تالت، بس صاحب المشروع هو اللي بيطلبها.

---

## 1. صاحب المشروع

### قرارات
| # | البند | الدليل إنه خلص |
|---|---|---|
| O1 | تأكيد قائمة الـ 31 صف 🔎 في `docs/data/ADMIN_MAPPING.md` («محتاجة مراجعتك»)، ومحافظات مدن هيئة المجتمعات (🔎 اقتراح)، ومسودة الأحياء | ردّك بـ «مؤكد». بعدها D1 |
| O2 | مدة الاحتفاظ بالإعلانات المنتهية والمحذوفة وصورها | قرار مكتوب في `DATA_INVENTORY.md` §4.1. بعدها D3 |
| O3 | مدة الاحتفاظ بالإشعارات، وسجل التواصل، وسجل المراجعة الآلية | قرار في `DATA_INVENTORY.md` §4.2. بعدها D3 |
| O4 | الجداول القديمة اللي ملهاش كاتب في الكود (`otp_requests`، `user_sessions`، `audit_log`، `business_profiles`، `service_bookings`، `user_blocks`): تتشال ولا تتوثّق | قرار. بعدها D4 |
| O5 | منطقة استضافة Supabase للإنتاج | المنطقة مكتوبة في `DATA_INVENTORY.md` §2 ومسودة الخصوصية |
| O6 | منطقة تخزين Sentry (US/EU) ومدة الاحتفاظ | مكتوبين في `DATA_INVENTORY.md` (صف Sentry) ومسودة الخصوصية |
| O7 | مزوّد الـ SMS النهائي (Twilio للتجربة بس) | اسم المزوّد. بعدها D5 |

### حسابات ومفاتيح (كلها `supabase secrets set` على المشروع، ومفيش ولا واحد في الريبو)
| # | البند | الدليل إنه خلص |
|---|---|---|
| O8 | مشروع Supabase إنتاج جديد على **خطة Pro**، وتفعيل Image Transformations | `curl -sI "https://<PROD_REF>.supabase.co/storage/v1/render/image/public/ads/<ملف>?width=200&format=webp"` يرجّع 200 و`content-type: image/webp` |
| O9 | مفتاح Anthropic (workspace إنتاج بحد إنفاق) | `deno test --config supabase/functions/deno.json --no-lock --allow-env --allow-net supabase/tests/live/anthropic_moderation.live.ts` |
| O10 | Firebase: service account و`google-services.json` و`GoogleService-Info.plist` | `supabase/tests/live/fcm.live.ts` مع `WASLA_TEST_FCM_TOKEN`، وإشعار يوصل لجهاز حقيقي |
| O11 | Paymob: حساب Live، وCallback على `payment-webhook` | `supabase/tests/live/paymob_sandbox.live.ts` على مفاتيح الـ test، وبعدين عملية حقيقية بمبلغ صغير ترجع `completed` في `transactions` |
| O12 | سر `KYC_NATIONAL_ID_HMAC_SECRET` للإنتاج (`openssl rand -hex 32`) مع نسخة احتياطية آمنة | `submit-kyc-request` على الإنتاج يرجّع 200 لطلب صحيح، مش 500 |
| O13 | مفتاح Google Maps مقصور على package التطبيق والـ bundle id | الخريطة بتظهر في نسخة release على جهاز (شاشة تحديد المكان، والخريطة في البحث) |
| O14 | تطبيق Meta (Facebook Login) بحالة Live | دخول بحساب Facebook حقيقي من نسخة release |
| O15 | Sentry: مشروع للتطبيق واللوحة والدوال، وDSN لكل واحد | خطأ تجريبي يظهر في Sentry من غير رقم ولا بريد (§7 في production plan) |
| O16 | مفتاح رفع Android (`upload.jks`) محفوظ برّه الريبو وله نسخة احتياطية، و`android/key.properties` | `apksigner verify --print-certs app-release.apk` يطلّع شهادة مفتاح الرفع مش debug |
| O17 | خدمة uptime على `/functions/v1/health` | الخدمة بتنبّه لما الرد مش 200 (تتجرّب بإيقاف مؤقت) |
| O18 | فك قفل الفوترة على GitHub عشان الـ CI يشتغل | آخر run على `fix/audit` كل الـ jobs فيه خضرا: `https://github.com/Maamoun0/wasla/actions` |
| O19 | جهاز Mac بـ Xcode لبناء iOS | `flutter build ipa --release` ينجح |

### إعدادات في لوحة Supabase للإنتاج (production plan §4)
| # | البند | الدليل إنه خلص |
|---|---|---|
| O20 | TOTP MFA مفعّل، وأول admin مسجّل TOTP | الدخول للوحة بيطلب الكود، وأي إجراء من غير `aal2` بيترفض |
| O21 | حدود الـ OTP بنفس قيم `config.toml`، **وصلاحية الكود 300 ثانية** (N18: الـ stack المحلي كان شغال بـ 6000) | لقطة من Authentication ← Rate Limits، و`sms_otp.live.ts` |
| O22 | Send SMS Hook على `send-sms-hook`، و**مفيش `test_otp`** على المشروع المستضاف | `supabase/tests/live/sms_otp.live.ts` مع `WASLA_TEST_PHONE` يوصل كود حقيقي |
| O23 | CAPTCHA (hCaptcha أو Turnstile) لدخول الموبايل (مستحسن) | محاولة دخول من غير CAPTCHA بتترفض |

## 2. مستشار قانوني
| # | البند | الدليل إنه خلص |
|---|---|---|
| L1 | مراجعة `docs/legal/PRIVACY_DRAFT.md` و`TERMS_DRAFT.md` على القانون 151 لسنة 2020 ولائحته، وملء الأقواس `[…]` | النص النهائي منشور في `app_configs` (`legal_terms`، `legal_privacy`) برقم إصدار جديد، والـ dialog بيطلب الموافقة عليه |
| L2 | تأكيد مدة الاحتفاظ بالمعاملات (5 سنين مقترحة) | قرار مكتوب. بعدها D2 |
| L3 | اتفاقيات معالجة البيانات (DPA) مع Supabase وAnthropic وFirebase/Google وPaymob ومزوّد الـ SMS وSentry | نسخة موقّعة أو مقبولة من كل واحد، ومذكورة في `DATA_INVENTORY.md` §2 |
| L4 | الحاجة لتسجيل أو ترخيص عند جهاز حماية البيانات الشخصية | رأي مكتوب |

## 3. مزوّد الخدمة (بيتطلب من صاحب المشروع)
| # | البند | الدليل إنه خلص |
|---|---|---|
| P1 | Paymob: تفعيل الحساب Live بعد مراجعة المستندات | عملية حقيقية ناجحة (O11) |
| P2 | مزوّد الـ SMS: تسجيل اسم المرسل (Sender ID) في مصر | الرسالة بتوصل باسم «Wasla» مش رقم (O22) |
| P3 | Meta: التطبيق Live | O14 |
| P4 | Google Play Console و App Store Connect: الحساب والصفحة وسياسة الخصوصية بالرابط | النسخة متاحة في internal testing على المتجرين |

## 4. المطوّر (Claude)
| # | البند | مستني | الدليل إنه خلص |
|---|---|---|---|
| D1 | migration المدن: P-codes، والاسم الرسمي، والبحث بالاسمين وبالأسماء البديلة، ونقل شبرا الخيمة وحدائق الأهرام، والهرم على EG2106، وفيصل تحت العمرانية | O1 | `npx -y supabase@2.120.0 test db` فيه اختبار إن كل محافظة ليها مدينة واحدة على الأقل ومفيش تكرار بعد التطبيع، وإن البحث بـ «الأهرام» و«فيصل» بيلاقي مناطقهم |
| D2 | 🟡19: محو المعاملات المجهولة بعد مدة الاحتفاظ | L2 | اختبار pgTAP لمعاملة أقدم من المدة بتتمسح، والأحدث بتفضل |
| D3 | حذف دوري للإعلانات المنتهية والإشعارات والسجلات | O2، O3 | اختبارات pgTAP لكل جدول، والـ cron متسجل (`select * from cron.job`) |
| D4 | شيل أو توثيق الجداول القديمة | O4 | migration جديدة، و`test db` ينجح |
| D5 | ملف المزوّد النهائي في `send-sms-hook/providers/` | O7 | اختبار Deno للمزوّد، و`sms_otp.live.ts` (O22) |
| D6 | **فيصل ← الطالبية** لما «قسم الطالبية» يظهر في مصدر رسمي أحدث (`ADMIN_MAPPING.md`) | مصدر جديد | migration تنقل الحي، واختبار البحث بـ «فيصل» |
| D7 | تشغيل كل الحزم على الفرع النهائي | — | `test db` و`deno test` واختبارات التكامل المحلية و`npm test` للوحة و`flutter analyze --fatal-infos --fatal-warnings` و`flutter test`، كلهم 0 فشل. ورحلة المحاكي: `flutter test integration_test/post_ad_journey_test.dart -d <emulator> --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=<anon>` |
| D8 | تجربة الرحلات الخمس على جهاز حقيقي بنسخة release موصولة بالإنتاج | O8 لـ O15 | الدخول بـ OTP، ونشر إعلان وقبوله من اللوحة، والبحث والتواصل، والدفع والترويج، والتوثيق. كل رحلة مسجّلة في التقرير |

## 5. اتأجل لبعد الإطلاق (مش مانع)
| البند | السبب |
|---|---|
| 🟡18 نقل النصوص لملفات الترجمة (529 نص في 45 ملف) | قرارك يوم 2026-11-01 |
| PostHog (تحليلات) | قرارك. لو اتضاف، لازم يدخل جرد البيانات ومسودة الخصوصية |
| المحادثة داخل التطبيق | مقفولة لنسخة 1.1 |
| WhatsApp كقناة OTP | `SMS_CHANNEL=whatsapp` محجوز ومش متنفّذ |
