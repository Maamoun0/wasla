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

## 2. مزوّد SMS (رموز OTP)

| | |
|---|---|
| المطلوب | **قرار منك:** أنهي مزوّد. Supabase Auth بيدعم Twilio وTwilio Verify وMessageBird وVonage وTextlocal. محتاج مزوّد بيوصل لأرقام مصر بسعر معقول |
| فين | لوحة Supabase ← Authentication ← Sign In / Providers ← Phone (مش Edge Function secret) |
| مع ده | حدود الـ OTP في Authentication ← Rate Limits، بنفس قيم `supabase/config.toml` (production plan §4) |
| للاختبار | في `supabase/functions/.env` أو في ملف تاني: `WASLA_DEV_SUPABASE_URL`، و`WASLA_DEV_SUPABASE_ANON_KEY` (مفتاح anon لمشروع dev)، و`WASLA_TEST_PHONE` (رقمك بصيغة `+2010…`) |

على مرحلتين، عشان الرمز بيوصل على موبايل حقيقي:

```bash
npx -y deno@2.1.4 test --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/sms_otp.live.ts
```

بعدها، والرمز اللي وصلك اسمه `<CODE>`:

```bash
WASLA_TEST_OTP=<CODE> npx -y deno@2.1.4 test --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/sms_otp.live.ts
```

**النجاح:** الرسالة توصل، والرمز يدخّلك ويرجع session. لو طلبت مرتين في أقل من 60 ثانية، الطلب التاني هيترفض، وده المطلوب.

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

---

## الحالة

| الخدمة | السر | الاختبار الحي | النتيجة |
|---|---|---|---|
| Anthropic | ⬜ | `anthropic_moderation.live.ts` | لم يُشغَّل |
| SMS | ⬜ (والمزوّد لم يُختر) | `sms_otp.live.ts` | لم يُشغَّل |
| Firebase | ⬜ | `fcm.live.ts` | لم يُشغَّل |
| Paymob Sandbox | ⬜ | `paymob_sandbox.live.ts` + الدورة اليدوية | لم يُشغَّل |
| KYC HMAC | ⬜ | `curl` أعلاه | لم يُشغَّل |
