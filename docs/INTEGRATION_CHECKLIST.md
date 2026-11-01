# قائمة ربط الخدمات الخارجية (Integration Checklist)

كل خدمة خارجية هنا: إيه المطلوب، فين يتحط، وإيه الأمر اللي بيثبت إنها شغالة فعلاً. كل الاختبارات الحية في `supabase/tests/live/`، وبتستخدم نفس الكود اللي بتستخدمه الدوال في الإنتاج. أي اختبار بيتخطّى نفسه لو السر بتاعه مش موجود، ومش بيشتغل في الـ CI.

> كل ده على مشروع **dev** بس. مشروع الإنتاج هيتعمل جديد وقت الإطلاق، بأسرار جديدة (`docs/wasla_production_migration_plan.md` §3).

## قبل ما تبدأ

1. **ماتبعتش الأسرار في الشات.** حطها في `supabase/functions/.env`، والملف ده متجاهَل في git (`.gitignore:7`، `*.env`). انسخه من `supabase/functions/.env.example`.
2. بعدها قوللي "جاهز"، وأنا هشغّل الأوامر اللي تحت. كلها بتقرا الملف بـ `--env-file`، فمفيش سر هيظهر في الأوامر ولا في التاريخ.
3. لرفع الأسرار لمشروع الـ dev (`<DEV_REF>`، ده اللي في `deploy_functions.bat`):

```bash
npx -y supabase@2.120.0 secrets set --project-ref <DEV_REF> --env-file supabase/functions/.env
```

> `supabase secrets set` بيرفع كل مفتاح موجود في الملف. سيب قيم الاختبار الخاصة بالجهاز (`WASLA_TEST_*` و`WASLA_DEV_*`) في ملف تاني لو مش عايزها تترفع، أو امسحها بعد الاختبار.

---

## 1. Anthropic (مراجعة الإعلانات بالـ AI)

| | |
|---|---|
| المطلوب | `ANTHROPIC_API_KEY` من [platform.claude.com](https://platform.claude.com)، ويفضّل workspace منفصل لـ dev مع حد إنفاق |
| اختياري | `MODERATION_MODEL_FAST` (الافتراضي `claude-haiku-5-5`)، `MODERATION_MODEL_DEEP` (الافتراضي `claude-sonnet-5-5`)، `MODERATION_TIMEOUT_MS` |
| فين | `supabase/functions/.env`، وبعدها `secrets set` |
| بيستخدمه | `create-ad` بس |
| من غيره | كل إعلان بيتسجّل `unreviewed` ويروح للمراجعة اليدوية. مفيش حاجة بتقع |

```bash
npx -y deno@2.1.4 test --config supabase/functions/deno.json --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/anthropic_moderation.live.ts
```

**النجاح:** إعلان عادي يتصنّف `low` من النموذج السريع (layer 2). وإعلان نصب واضح يعدّي فلتر الكلمات، يتصنّف `medium` أو `high`، ويوصل للنموذج العميق (layer 3). ومن غير أي `error` (اسم نموذج غلط، أو مفتاح، أو parsing). التكلفة: أقل من سنت.

## 2. رسائل SMS عن طريق Send SMS Hook

Auth مش مربوط بأي مزوّد مدمج. Auth بيبعت كل OTP لـ Edge Function اسمها `send-sms-hook`، والطلب متوقّع بـ Standard Webhooks. الدالة بتختار المزوّد من `SMS_PROVIDER`. أول تنفيذ هو Twilio، وده للتجربة بس. أي مزوّد محلي بعد كده = ملف جديد في `send-sms-hook/providers/` وسطر واحد في `registry.ts`.

| | |
|---|---|
| المطلوب (Twilio) | `TWILIO_ACCOUNT_SID`، و`TWILIO_AUTH_TOKEN`، و`TWILIO_FROM` (رقم Twilio) أو `TWILIO_MESSAGING_SERVICE_SID` |
| الدالة | `SMS_PROVIDER=twilio`، و`SMS_CHANNEL=sms` (الافتراضي، و`whatsapp` محجوز لسه ومش متنفّذ)، و`SMS_TIMEOUT_MS` (الافتراضي 4000، لأن Auth بيدّي الـ hook كله 5 ثواني) |
| فين | `supabase/functions/.env`، وبعدها `secrets set` |
| تفعيل الـ hook | لوحة Supabase ← Authentication ← Hooks ← Send SMS ← HTTPS ← `https://<DEV_REF>.supabase.co/functions/v1/send-sms-hook`، وبعدين **Generate secret**. القيمة اللي بتطلع (`v1,whsec_…`) حطها في `SEND_SMS_HOOK_SECRETS` في `supabase/functions/.env`، وارفعها بـ `secrets set` |
| Phone provider | Authentication ← Sign In / Providers ← Phone: لازم يكون **مفعّل**. مع تفعيل الـ hook، Auth مش بيستخدم المزوّد المدمج |
| النشر | `npx -y supabase@2.120.0 functions deploy send-sms-hook --project-ref <DEV_REF> --no-verify-jwt` (Auth بيندهها قبل ما يكون فيه JWT. التوقيع هو اللي بيحميها) |
| مع ده | حدود الـ OTP في Authentication ← Rate Limits، بنفس قيم `supabase/config.toml` (production plan §4). Auth بيطبّقها قبل ما يندَه الـ hook |
| للاختبار | `WASLA_TEST_PHONE` (رقمك بصيغة `+2010…`)، و`WASLA_DEV_SUPABASE_URL`، و`WASLA_DEV_SUPABASE_ANON_KEY` |

**أولاً المزوّد لوحده** (قبل النشر). بيبعت رسالة اختبار واحدة:

```bash
npx -y deno@2.1.4 test --config supabase/functions/deno.json --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/sms_otp.live.ts
```

لو `WASLA_DEV_*` موجودين والـ hook متنشر، نفس الأمر كمان بيطلب OTP حقيقي من Auth. وبعدها، والرمز اللي وصلك اسمه `<CODE>`:

```bash
WASLA_TEST_OTP=<CODE> npx -y deno@2.1.4 test --config supabase/functions/deno.json --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/sms_otp.live.ts
```

**النجاح:**
- رسالة الاختبار توصل.
- رسالة الـ OTP توصل بالعربي ("رمز التحقق في وصلة: …").
- الرمز يدخّلك ويرجع session.
- طلب تاني في أقل من 60 ثانية يترفض.
- في Edge Function logs: سطر `sent via twilio (sms) to ***XYZ`، ومن غير الرمز.

**محلياً:** الـ hook بيتنده على Twilio وهمي، والسلسلة كلها متغطّية في `supabase/tests/auth/send_sms_hook.local.ts`. الإعداد في `supabase/.env` (انسخه من `supabase/.env.example`).

## 3. Firebase (الإشعارات)

| | |
|---|---|
| المطلوب | Service account JSON من Firebase Console ← Project settings ← Service accounts ← Generate new private key |
| فين | `FIREBASE_SERVICE_ACCOUNT` في `supabase/functions/.env`، **الـ JSON كله في سطر واحد**، وبعدها `secrets set` |
| بيستخدمه | `dispatch-notifications`، وبيشتغل بـ cron. ولازم أسرار Vault `project_url` و`service_role_key` تكون موجودة (production plan §3) |
| في التطبيق | `google-services.json` في `frontend/mobile/wasla/android/app/` و`GoogleService-Info.plist` لـ iOS. دول ملفات إعداد مش أسرار، بس متجاهَلين في git |
| اختياري | `WASLA_TEST_FCM_TOKEN`: توكن جهاز من log نسخة debug من التطبيق، عشان يوصل إشعار حقيقي |

```bash
npx -y deno@2.1.4 test --config supabase/functions/deno.json --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/fcm.live.ts
```

**النجاح:** الـ service account ياخد OAuth token، وFCM مايرجعش 403. ولو حطيت توكن جهاز، الإشعار يوصل فعلاً.

## 4. Paymob Sandbox (الدفع)

| | |
|---|---|
| المطلوب | من حساب Paymob في **Test mode**: `PAYMOB_API_KEY`، و`PAYMOB_INTEGRATION_ID` (integration بطاقة، test)، و`PAYMOB_IFRAME_ID`، و`PAYMOB_HMAC_SECRET` |
| فين | `supabase/functions/.env`، وبعدها `secrets set` |
| بيستخدمه | `create-payment` (الثلاثة الأولى) و`payment-webhook` (الـ HMAC) |
| في لوحة Paymob | Transaction processed callback = `https://<DEV_REF>.supabase.co/functions/v1/payment-webhook` |

```bash
npx -y deno@2.1.4 test --config supabase/functions/deno.json --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/paymob_sandbox.live.ts
```

**النجاح:** auth ثم order ثم payment key ثم صفحة دفع بترجع 200. مفيش فلوس بتتحرك.

**بعدها، الدورة الكاملة** (يدوي، على مشروع dev بعد `supabase functions deploy`): من التطبيق اشتري باقة تمييز، وادفع ببطاقة الاختبار من توثيق Paymob Sandbox. بعدها شغّل في SQL editor:

```sql
select status, gateway_transaction_id, completed_at from transactions order by created_at desc limit 1;
select boost_type, expires_at from ad_boosts order by created_at desc limit 1;
```

**النجاح:** المعاملة `completed`، والتمييز اتفعّل بمدة الباقة. ده بيثبت إن الـ webhook وصل وإن الـ HMAC اتطابق.

## 5. سر الـ HMAC للرقم القومي (KYC)

| | |
|---|---|
| المطلوب | 32 حرف عشوائي على الأقل: `openssl rand -hex 32`. ده مش من خدمة خارجية، بتولّده إنت |
| فين | `KYC_NATIONAL_ID_HMAC_SECRET` في `supabase/functions/.env`، وبعدها `secrets set`. **مش** في قاعدة البيانات ولا في الريبو |
| بيستخدمه | `submit-kyc-request`. من غيره، الدالة بترفض كل الطلبات (500) |
| تحذير | **ماتغيّروش بعد ما يبدأ الاستخدام.** تغييره بيبطّل كشف التكرار للطلبات القديمة (privacy plan §4). قيمة dev غير قيمة الإنتاج |

بعد `secrets set` و`supabase functions deploy submit-kyc-request`:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "https://<DEV_REF>.supabase.co/functions/v1/submit-kyc-request" -H "Authorization: Bearer <DEV_ANON_KEY>"
```

**النجاح:** `401`، يعني السر موجود والدالة وصلت لمرحلة التحقق من المستخدم. `500` يعني السر ناقص أو أقصر من 32 حرف. والمنطق نفسه (التطبيع، والتكرار، وعدم تخزين الرقم) متغطي في pgTAP 16، وفي `submit-kyc-request/handler_test.ts`، وفي `supabase/tests/kyc/kyc_flow.local.ts`.

## 6. Google Maps (الخريطة وتحديد مكان الإعلان)

| | |
|---|---|
| المطلوب | API key من Google Cloud، مفعّل عليه **Maps SDK for Android** و**Maps SDK for iOS**، ومقصور على package `com.ahmedmaamoun.wasla` وعلى bundle id بتاع iOS |
| Android | متغير البيئة `MAPS_API_KEY` وقت البناء، أو سطر `MAPS_API_KEY=…` في `frontend/mobile/wasla/android/local.properties` (مش في git) |
| iOS | ملف `frontend/mobile/wasla/ios/Flutter/Maps.xcconfig` (مش في git) فيه `MAPS_API_KEY = …` |
| بيستخدمه | شاشة تحديد المكان في نشر الإعلان، وعرض الخريطة في البحث (🟡13). الاتنين ماكانوش هيشتغلوا قبل كده، لأن المفتاح كان placeholder مكتوب في الكود |

```bash
MAPS_API_KEY=<KEY> flutter build apk --debug
```

**النجاح:** على جهاز، افتح البحث ← زرار الخريطة. الإعلانات تظهر مجمّعة، والضغط على مجموعة بيقرّب، والضغط على إعلان لوحده بيفتح صفحته. وشاشة تحديد المكان في نشر الإعلان بتعرض الخريطة.

## 7. Facebook (تسجيل الدخول)

| | |
|---|---|
| المطلوب | تطبيق على Meta for Developers فيه **Facebook Login**، والـ App ID والـ App Secret |
| فين | لوحة Supabase ← Authentication ← Providers ← Facebook. وفي تطبيق Meta، الـ Valid OAuth Redirect URI هو `https://<DEV_REF>.supabase.co/auth/v1/callback` |
| التطبيق | زرار "تابع بـ Facebook" بيرجع على `wasla://login-callback` (نفس جوجل). وبعد الدخول بيطلب الموافقة على الشروط لو مااتسجلتش |
| مراجعة Meta | الصلاحيات المطلوبة `email` و`public_profile` بس، وطلبهم مابيحتاجش App Review. التطبيق لازم يبقى Live عشان أي حد يدخل |

**النجاح:** على جهاز، دوس "تابع بـ Facebook". المفروض يتفتح Facebook، وبعد الموافقة ترجع للتطبيق وإنت داخل، ويطلع حساب جديد في Authentication ← Users بالـ provider `facebook`.

## 8. المراقبة (NFR-3.1)

| | |
|---|---|
| جاهز | دالة `health`: بترجع 200 لو قاعدة البيانات وStorage شغالين، و503 مع اسم الفحص اللي فشل لو لأ. من غير أي تفاصيل خطأ أو أسرار |
| فين | أي خدمة uptime (UptimeRobot، Better Stack…) بتعمل GET على `https://<REF>.supabase.co/functions/v1/health` كل دقيقة، وتنبّه لو الرد مش 200 |
| Sentry | جاهز في الكود ومقفول لحد ما الـ DSN يتحدد: `SENTRY_DSN` للتطبيق (`--dart-define`)، و`SENTRY_DSN`/`NEXT_PUBLIC_SENTRY_DSN` للوحة، و`SENTRY_DSN` كسر للدوال (production plan §7). PostHog اتأجل |

```bash
curl -s -o /dev/null -w "%{http_code}
" https://<DEV_REF>.supabase.co/functions/v1/health
```

---

## الحالة

| الخدمة | السر | الاختبار الحي | النتيجة |
|---|---|---|---|
| Anthropic | ⬜ | `anthropic_moderation.live.ts` | لم يُشغَّل |
| SMS (hook + Twilio) | ⬜ | `sms_otp.live.ts` | لم يُشغَّل |
| Firebase | ⬜ | `fcm.live.ts` | لم يُشغَّل |
| Paymob Sandbox | ⬜ | `paymob_sandbox.live.ts` + الدورة اليدوية | لم يُشغَّل |
| KYC HMAC | ⬜ | `curl` أعلاه | لم يُشغَّل |
| Google Maps | ⬜ | تجربة على جهاز | لم يُشغَّل |
| Facebook | ⬜ | تجربة على جهاز | لم يُشغَّل |
