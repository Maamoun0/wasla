# تقرير التدقيق — المرحلة الأولى (الاستكشاف والجرد)

- **التاريخ:** 2026-10-26
- **الفرع:** `develop` @ `333e1e7` + تعديلات غير مُرسَلة (uncommitted) في شجرة العمل
- **النطاق:** قراءة فقط. لم يُعدَّل أي سطر كود. الملف الوحيد المُضاف هو هذا التقرير.
- **منهج الأدلة:** كل حكم مرفق إما بمخرجات أمر فعلي أو بمسار ملف + رقم سطر. الأدلة الحية لقاعدة البيانات جاءت من تطبيق ملفات SQL الموجودة في الريبو على حاوية `supabase/postgres:15.8.1.085` مؤقتة (التفاصيل في §3.4).

---

## 1. الخلاصة التنفيذية

**الحالة المعلنة "Sprints 0–7 مكتملة ومختبرة" غير صحيحة.** لا يوجد دليل اختبار لها، والكود يحتوي على ثغرات حرجة قابلة للاستغلال اليوم:

| # | الثغرة | الدليل |
|---|---|---|
| C1 | **أي مستخدم مسجَّل يرقّي نفسه إلى `admin` ويضع `is_id_verified=true`** — سياسة `users_update_own` بلا `WITH CHECK` ولا حماية للأعمدة | Probe P3: `UPDATE 1 → user_type=admin, is_admin()=t` — `backend/database/wasla-schema.sql:853` |
| C2 | **أي مستخدم يضع رصيده (`user_credits.balance`) لأي قيمة** | Probe P4: `balance = 999999.00` — `wasla-schema.sql:956` |
| C3 | **دوال الإشراف `moderate_ad` / `moderate_kyc` / `handle_report` و`create_ad_transaction` هي `SECURITY DEFINER`، قابلة للتنفيذ من `anon` و`authenticated`، وتأخذ هوية المشرف/المالك من المُستدعي** | Probe P0c (كلها `t/t`)؛ P14: مستخدم عادي اعتمد KYC لنفسه `{"success": true}`؛ P8: مستخدم أنشأ إعلاناً باسم مستخدم آخر |
| C4 | **إدراج طلب KYC بحالة `approved` مباشرة** — سياستا INSERT متداخلتان (OR) وإحداهما بلا شرط حالة | Probe P13: `status = approved` — `archive/sprint10_security_legal.sql:57` |
| C5 | **مبلغ الدفع ونوع/مدة الـ Boost يأتيان من العميل** — يمكن دفع 1 جنيه مقابل Featured لمدة 365 يوماً | `supabase/functions/create-payment/index.ts:324,421,443`؛ `payment-webhook/index.ts:173-174`؛ لا مقارنة لـ `amount_cents` مع المبلغ المخزَّن |
| C6 | **لوحة الإدارة بلا تحقق صلاحيات على السيرفر** — كل الصفحات تستخدم `service_role` دون فحص دور؛ `getSignedUrl` (Server Action) **بلا أي تحقق هوية** ويولّد روابط لمستندات الهوية | `frontend/admin/app/dashboard/kyc/actions.ts:32-48`؛ `middleware.ts:23-30` (فحص الدور فارغ عمداً)؛ الدور يُقرأ من `user_metadata` القابل للتعديل من المستخدم |
| C7 | **`wasla-schema.sql` يبدأ بـ `DROP SCHEMA public CASCADE`** وخطة الإنتاج تطلب تشغيله أولاً على Production → مسح كامل للبيانات + فقدان صلاحيات Supabase الافتراضية (`anon`/`authenticated`) | `backend/database/wasla-schema.sql:11-12`؛ `docs/wasla_production_migration_plan.md:7`؛ تحقّقت فعلياً: بعد تطبيقه `has_schema_privilege('anon','public','USAGE') = f` |
| C8 | **قراءة أرقام هواتف وبريد كل المستخدمين لأي زائر (`anon`)** | Probe P2: `rows_visible_to_anon=2, phones=+2010…01,+2010…02` — `wasla-schema.sql:852` |

**عوائق تشغيل (Blockers):**
- لوحة الإدارة **لا تُبنى**: `npm ci` يفشل (لا `package-lock.json`)، و`next build` يفشل (`Can't resolve '@/lib/supabase'` — لا يوجد `tsconfig.json`)، ولا يوجد إعداد ESLint ولا Tailwind ولا اختبارات. وحتى لو بُنيت، كل Server Action تستدعي `auth.getUser()` على عميل `service_role` بلا جلسة → `user = null` → كل إجراء إداري يرجع "غير مصرح".
- **اعتماد أي إعلان يفشل** (موثّق فعلياً): trigger `trg_notify_ad_status` يستدعي `net.http_post` و`current_setting('app.settings.supabase_url')` — امتداد `pg_net` لا يُنشأ في أي ملف، والإعدادات `app.settings.*` غير معرَّفة في الريبو → `ERROR: unrecognized configuration parameter` ويُلغى الاعتماد بالكامل.
- **لا يوجد `supabase/migrations/` ولا `seed.sql`** → `supabase db reset` يُنتج قاعدة فارغة. المخطط موزّع على 25 ملف SQL بلا ترتيب معرَّف، 4 منها تفشل عند التطبيق (§3.4).
- **حذف الحساب لا يعمل**: Flutter يكتب في `account_deletion_requests` (`settings_screen.dart:122`) وهو جدول غير موجود (Probe P10)؛ وحذف المستخدم من `auth.users` يفشل بمجرد وجود سجل في `audit_logs` (Probe P12: `actor_id NOT NULL` مع `ON DELETE SET NULL`).
- **إشعارات FCM غير منفّذة**: الدالتان `notify-ad-status` و`notify-watchlist-match` تطبعان الـ payload في الـ log فقط ولا ترسلان شيئاً (`notify-ad-status/index.ts:52-58`، `notify-watchlist-match/index.ts:77-84`).

**المشكلة المعروفة (Post Ad Wizard):** السبب الجذري مُثبَت. الـ seed الوحيد (`database/seed_category_fields.sql`) يربط الحقول بالأقسام **الرئيسية** 2/3/4 فقط، بينما المعالج يحفظ معرّف القسم **الفرعي** (`select_category_screen.dart:93`). النتيجة الفعلية من القاعدة (Probe P9): الأقسام الفرعية الـ 34 لديها **0 حقول**، والأقسام "خدمات" و"سلع" ليس لها حقول على أي مستوى. استعلام Flutter (`category_fields_provider.dart:6-10`) صحيح نحوياً لكنه لا يرث حقول القسم الأب. والـ seed نفسه خارج أي migration.

---

## 2. اختلافات بين السياق المُعطى والكود الفعلي

| البند في المهمة | الواقع في الريبو | الدليل |
|---|---|---|
| SRS بـ 56 متطلباً | **28 متطلباً**: 20 وظيفياً (FR-1.1…FR-6.2) + 8 غير وظيفية (NFR-1.1…NFR-4.2) | `docs/wasla_srs.md` |
| خطة تنفيذ 13 Sprint | خطة المهام فيها **5 سبرينتات**؛ قوائم التنفيذ الداخلية تغطي **Sprint 0–12 (13 ملفاً)**، ولا يوجد Sprint 13 | `docs/wasla_sprint_task_plan.md`؛ `docs/internal/sprints/` |
| Sprints 0–7 مكتملة ومختبرة | **صفر بنود مؤشَّرة** في كل القوائم ما عدا Sprint 2 (15 من 20) | عدّ `☐` مقابل `☑/✔/[x]`: مثلاً sprint1 = 16/0، sprint7 = 13/0 |
| منصة للعمالة غير الرسمية والخدمات المنزلية | الـ SRS والـ seed يصفان **منصة إعلانات مبوّبة عامة** (خدمات، وظائف، عقارات، سيارات، سلع)؛ الخدمات قسم من خمسة | `wasla_srs.md` §1؛ `wasla-schema.sql:1081-1086` |
| مجلد `supabase/` يحتوي migrations وseed | يحتوي فقط `config.toml` (3 أسطر إعداد) و`functions/` | `ls supabase` |
| مسار اللوحة `admin/` | `frontend/admin/` | — |
| شات وRealtime | جداول `conversations`/`messages` موجودة وشاشات شات في Flutter؛ **لا يوجد أي `ALTER PUBLICATION supabase_realtime`** في الريبو، والشات ليس ضمن الـ SRS | `grep publication` = 0 نتائج |
| إشراف محتوى بـ Claude بثلاث طبقات | موجود (RegEx → Haiku → Sonnet) لكن بنماذج `claude-3-5-haiku-20241022` / `claude-3-5-sonnet-20241022` المتقاعدة؛ والنتيجة تُخزَّن كتلميح فقط ولا تؤثّر على حالة الإعلان | `ai-content-review/index.ts:100,114`؛ `create_ad_transaction.sql:57,101-106` |
| مشروع Supabase واحد | **مشروعان**: `fgvjjtbtlzjpzaqypzmz` (في git) و`bizikadaucsyevdoagmm` (في التعديلات غير المُرسَلة وفي `deploy_functions.bat`). أيّهما Production غير موثّق | `git diff app_constants.dart` |

---

## 3. نتائج الأوامر الفعلية

### 3.1 Flutter (`frontend/mobile/wasla`) — Flutter 3.41.9 / Dart 3.11.5
| الأمر | النتيجة |
|---|---|
| `flutter pub get` | ✅ exit 0 (154 حزمة لها إصدارات أحدث غير متوافقة مع القيود) |
| `flutter analyze` | ❌ **exit 1 — 15 مشكلة**: 13 warning (`invalid_annotation_target` في `chat_models.dart:10-33`)، 1 `avoid_print` (`ai_ad_analyzer_provider.dart:26`)، 1 `use_build_context_synchronously` (`boost_ad_screen.dart:346`). خطوة CI `flutter analyze` ستفشل بهذا |
| `flutter test --coverage` | ✅ **41/41 ناجحة** |
| التغطية | **44.1%** (246/558 سطراً) — لكن محسوبة على **7 ملفات فقط** حمّلتها الاختبارات من أصل **60** ملف مصدر؛ الـ 53 الباقية 0%. التغطية الحقيقية للمشروع أقل بكثير من 44% والهدف 70% |
| `build_runner` | لم يُشغَّل؛ الملفات المولَّدة (`*.g.dart`, `*.freezed.dart`) مُرسَلة في الريبو لـ 4 ملفات فقط |
| `flutter build apk --release` | لم يُشغَّل في هذه المرحلة |

لا يوجد `integration_test/`. لا توجد اختبارات widget للشاشات الأساسية باستثناء `PaymentWebViewScreen`.

### 3.2 لوحة الإدارة (`frontend/admin`) — Next.js 14.2.4
| الأمر | النتيجة |
|---|---|
| `npm ci` | ❌ exit 1 — لا يوجد `package-lock.json` |
| `npm install` (في نسخة مؤقتة خارج الريبو) | ✅، مع تحذير: `next@14.2.4: This version has a security vulnerability` |
| `next build` | ❌ **فشل**: `Module not found: Can't resolve '@/lib/supabase'` و`'@/components/…'` — لا `tsconfig.json` لتعريف alias `@/` |
| `npm run lint` | ❌ لا يوجد إعداد ESLint (يطلب إعداداً تفاعلياً) |
| `npm test` | ❌ لا يوجد سكربت test ولا أي اختبار |

أيضاً: `middleware.ts:3` يستورد `next/request` (غير موجود؛ النوع في `next/server`). لا يوجد `tailwind.config` ولا `postcss.config` رغم استخدام Tailwind. Next.js 14.2.4 متأثر بثغرة تجاوز الـ middleware (CVE-2025-29927) — والـ middleware هو خط الحماية الوحيد هنا.

### 3.3 Edge Functions (`supabase/functions`) — Deno 2.1.4
| الأمر | النتيجة |
|---|---|
| `deno check` لكل دالة (10) | ✅ exit 0 للعشر |
| `deno lint` | ❌ **17 مشكلة**: 16 `no-explicit-any` و1 `no-unused-vars` |
| اختبارات | ❌ لا يوجد أي اختبار، ولا اختبار HMAC |

### 3.4 قاعدة البيانات
- `supabase` CLI غير مثبّت، و**لا يوجد `supabase/migrations/`** → `supabase db reset` لا يطبّق أي schema. لم أشغّل `supabase start` لأن النتيجة محسومة (لا يوجد ما يُطبَّق).
- **البديل المنفَّذ:** حاوية `supabase/postgres:15.8.1.085` مؤقتة، طُبّقت عليها 22 ملف SQL بالترتيب الأكثر منطقية (لا يوجد ترتيب موثّق)، مع prelude يحاكي ما يوفّره Supabase المستضاف (عمود `auth.users.phone` من GoTrue، أعمدة `storage.buckets`، والصلاحيات الافتراضية لـ `anon/authenticated/service_role` التي يحذفها `DROP SCHEMA`). حُذفت الحاوية بعد الانتهاء. السكربتات في مجلد scratchpad الخاص بالجلسة (غير مُرسَلة في الريبو).

**أخطاء التطبيق:**
| الملف | الخطأ |
|---|---|
| `archive/sprint7_pre_improvements.sql:15` | `column "ai_risk_level" does not exist` |
| `archive/sprint10_security_legal.sql:33,44,67` | `column "role_id" does not exist` ×3 — سياسات audit/activity/KYC للمشرفين **لم تُنشأ** |
| `enhancements_v1.sql:20` | `syntax error at or near "("` — دالة `normalize_arabic` للبحث العربي **لم تُنشأ** |
| (اعتماد إعلان) | `unrecognized configuration parameter "app.settings.supabase_url"` |

ملفات أخرى ليست migrations: `wasla_core_schema_v2.sql` و`wasla_extended_schema_v2.sql` (مخطط بديل متعارض يستخدم `role_id`)، `wasla_mamp_preview.sql` (MySQL)، `archive/sprint1_verification_mock.sql` (**trigger يعتمد KYC تلقائياً بناءً على الاسم — mock في مسار قد يصل للإنتاج**).

**جداول RLS معطّل عليها** (Probe P0): `app_configs`, `categories`, `category_fields`, `cities`, `districts`, `governorates`, `permissions`, `role_permissions`, `roles`, `subscription_plans`, `user_roles`, `watchlist_notifications`. مع صلاحيات Supabase الافتراضية = **قابلة للكتابة من `anon`** (أي زائر يغيّر الأسعار في `subscription_plans` أو إعدادات `app_configs`).

**دوال `SECURITY DEFINER` بلا `search_path`** (P0b): `calculate_user_trust_score`, `create_ad_transaction`, `handle_report`, `is_admin`, `is_moderator`, `moderate_ad`, `moderate_kyc`, `protect_ad_sensitive_fields`.

**ما يعمل كما يجب:** إدراج `transactions` مباشرة من العميل مرفوض (P6)، إدراج `ad_boosts` مباشرة مرفوض (P7)، `trg_protect_ad_fields` يمنع المستخدم العادي من تغيير `status/is_featured` (لكنه يُتجاوز بعد C1)، bucket `id-documents` خاص (`public=f`, حد 1MB, jpeg/png).

### 3.5 فحص الأسرار
- **لا يوجد مفتاح سري مكشوف** في الملفات أو في كل تاريخ git (`git log --all -p`): بحثت عن JWT، `sk-ant-`، `sk_live`، مفاتيح Google، Paymob، private keys، service accounts.
- كل JWT موجود (2) فُكّ وتأكّد أنه `"role":"anon"` (مفتاح عام بطبيعته):
  - `fgvjjtbtlzjpzaqypzmz` — في تاريخ git (`app_constants.dart:151` في `HEAD`)
  - `bizikadaucsyevdoagmm` — في تعديلات غير مُرسَلة: `app_constants.dart:151`، و`scripts/{check_db,generate_inserts,insert_all,verify_ad_flow}.py` كقيمة افتراضية
- `google-services.json` موجود على القرص ومُستبعَد بـ `.gitignore` ولم يُرسَل في أي commit.
- ملاحظة: `AppConfig.paymobApiKey` معرَّف في تطبيق الموبايل (`app_constants.dart:153`) — فارغ افتراضياً، لكن مفتاح Paymob لا يجب أن يصل للعميل أصلاً.

---

## 4. مصفوفة التتبع (Traceability Matrix) — 28 متطلباً

✅ مكتمل ومُتحقق — ⚠️ جزئي — ❌ غير موجود — 🐛 موجود لكن مكسور

| Req | الوصف | DB | Backend/Edge | Flutter | Admin | Tests | الحالة | الدليل |
|---|---|---|---|---|---|---|---|---|
| FR-1.1 | تسجيل بالهاتف + OTP 6 أرقام | `otp_requests` | `request-otp` (حد لكل رقم فقط، لا IP) | `auth_provider.dart:57-127` | — | ❌ | ⚠️ | التطبيق يتجاوز الـ rate limit بالرجوع لـ `signInWithOtp` مباشرة (`auth_provider.dart:88`)؛ رسالة الخطأ تكشف رقم/كود اختبار للمستخدم (`:117`)؛ مزوّد SMS غير مُتحقق |
| FR-1.2 | تسجيل اجتماعي Google + Facebook | — | — | Google فقط `auth_provider.dart:147` | — | ❌ | ⚠️ | Facebook: 0 نتائج بحث |
| FR-1.3 | إعداد الملف (مدينة، اسم، صورة) | `users.city_id` | — | `profile_setup_screen.dart` | — | ❌ | ⚠️ | لا يوجد اختيار مدينة في الشاشة (`grep city` = 0)؛ bucket `avatars` غير مُنشأ في أي SQL |
| FR-1.4 | KYC: وجه/ظهر + سيلفي + مطابقة + شارة | `user_verifications` | `submit-kyc-request`, `get-kyc-document` | `verification_screen.dart` | `kyc/` | ❌ | 🐛 | لا سيلفي ولا مطابقة وجه؛ اعتماد ذاتي (P13/P14)؛ `moderate_kyc` لا يضبط `is_id_verified` (`rpc_moderate_kyc.sql:38-44`) فالشارة لا تظهر أبداً؛ اللوحة تقرأ bucket `kyc-documents` والدالة تكتب في `id-documents`؛ الرقم القومي يُخزَّن نصاً واضحاً (الخطة تطلب pgcrypto) |
| FR-2.1 | Feed حسب موقع GPS | `location_point` (elite_v3) | — | — | — | ❌ | ❌ | لا استخدام لـ `geolocator` في `lib/` |
| FR-2.2 | بحث نصي عربي بالمرادفات والأخطاء | `advanced_search_ads` | — | `explore_screen.dart:33` | — | ❌ | 🐛 | `AdsFilter.query` لا يُطبَّق على الاستعلام أبداً (`ads_provider.dart:132-142`) → مربع البحث لا يفعل شيئاً؛ `normalize_arabic` فشلت (syntax error) |
| FR-2.3 | فلاتر: قسم، سعر، مدينة، حي، نوع، تاريخ | فهارس موجودة | — | `ads_provider.dart:137-142` | — | ❌ | ⚠️ | لا فلتر حي ولا تاريخ؛ فلتر القسم الرئيسي يرجع صفراً لأن الإعلانات تُحفظ بمعرّف فرعي |
| FR-2.4 | عرض خريطة مع Clusters | — | — | — | — | ❌ | ❌ | `GoogleMap` يُستخدم فقط لاختيار الموقع (`location_price_screen.dart:504`)؛ مفتاح Maps placeholder في `AndroidManifest.xml`/`AppDelegate.swift` (تعديل غير مُرسَل) |
| FR-3.1 | معالج 5 خطوات، حتى 8 صور | `ad_media` | `create-ad` | `post_ad/` (6 شاشات) | — | `post_ad_wizard_test.dart` | ⚠️ | حد 8 صور في العميل فقط (`add_photos_screen.dart:24`)؛ لا تحقق في الخادم؛ لا integration test |
| FR-3.2 | حقول ديناميكية حسب القسم | `category_fields` | `create-ad` (بلا تحقق إلزامية/نوع) | `dynamic_field_builder.dart` | — | ❌ | 🐛 | Probe P9: 34 قسماً فرعياً = 0 حقول |
| FR-3.3 | معلَّق → مراجعة → نشط 30 يوماً | `expire-ads` cron | `moderate_ad` | `my_ads_screen.dart` | `ads/` | ❌ | 🐛 | الاعتماد يفشل (trigger `pg_net`)؛ `expires_at` يُحسب من الإنشاء لا من الاعتماد؛ لا تمديد |
| FR-4.1 | مفضلة + ملاحظات | `favorites.notes` | — | `saved_screen.dart:79-163` | — | ❌ | ⚠️ | العرض موجود؛ لم أجد تحريراً للملاحظة؛ غير مختبر |
| FR-4.2 | بحث محفوظ + إشعار فوري | `saved_searches`, trigger | `notify-watchlist-match` | `saved_screen.dart:205` | — | ❌ | 🐛 | الإرسال `console.log` فقط؛ الـ trigger يعتمد على `pg_net` و`app.settings` غير المعرّفين؛ الدالة بلا تحقق هوية |
| FR-4.3 | تسجيل نقرات الاتصال/واتساب | `contact_logs` | — | `ads_provider.dart:253` | — | ❌ | ⚠️ | سياسة الإدراج `WITH CHECK (TRUE)` (`wasla-schema.sql:896`) → تزوير/إغراق الإحصائيات |
| FR-4.4 | تقييم 1-5 + رد واحد للمعلن | `reviews`, `review_responses UNIQUE(review_id)` | — | `reviews_controller.dart`, `my_reviews_screen.dart` | — | `trust_score_calculation_test.dart` | ⚠️ | منطق الأهلية في trigger؛ غير مختبر ضد القاعدة |
| FR-5.1 | Paymob (بطاقة، فوري، محفظة) | `transactions` | `create-payment`, `payment-webhook` | `payment_webview_screen.dart` | — | widget test فقط | 🐛 | C5؛ idempotency عبر check-then-update غير ذرّي؛ `credit_purchase` لا يضيف رصيداً عند النجاح؛ بيانات billing افتراضية `test@wasla.eg` / `+201000000000` (`create-payment/index.ts:455-456`) |
| FR-5.2 | Featured / Urgent / Bump | `ad_boosts`, cron | webhook | `boost_ad_screen.dart`, `boost_controller.dart` | — | `monetization_test.dart` | 🐛 | النوع والمدة من `metadata` العميل |
| FR-5.3 | اشتراكات تجارية بحدود أعلى | `subscription_plans` (RLS معطّل) | webhook | `subscription_screen.dart` | — | `monetization_test.dart` | 🐛 | مدة ثابتة 30 يوماً؛ لا يوجد فرض لحدود الإعلانات في أي مكان؛ أي زائر يعدّل جدول الخطط |
| FR-6.1 | مراجعة الإعلانات + سبب + إشعار | `ad_moderation_log` | `moderate_ad` | — | `ads/` | ❌ | 🐛 | اللوحة لا تُبنى؛ Server Action ترجع غير مصرح دائماً؛ الدالة بلا فحص مشرف (C3)؛ الإشعار غير مُرسَل |
| FR-6.2 | بلاغات + حظر | `reports`, `audit_logs` | `handle_report` | بلاغ من `ad_detail_screen.dart:532` | `reports/`, `users/` | ❌ | 🐛 | نفس عيوب FR-6.1؛ enum الحالة لا يحتوي `banned` (`wasla-schema.sql:30`) واللوحة ترسل `banned` |
| NFR-1.1 | الصفحة الرئيسية ≤ 2 ثانية | فهارس | — | pagination موجود | — | `scripts/wasla-load-test.js` لم يُشغَّل | ❌ | لا قياس |
| NFR-1.2 | ضغط تلقائي وتحويل WebP على السيرفر | — | — | `imageQuality: 80, maxWidth: 1600` على العميل | — | ❌ | ❌ | `grep webp` = 0 |
| NFR-2.1 | HTTPS/TLS | — | Supabase/Paymob https | — | — | ❌ | ⚠️ | الافتراضي https؛ لم يُتحقق من إعدادات الإنتاج |
| NFR-2.2 | مستندات الهوية خاصة + روابط مؤقتة للمشرف | bucket خاص (P11) | `get-kyc-document` (300 ثانية) | — | `getSignedUrl` | ❌ | 🐛 | C6 (رابط بلا تحقق)؛ فحص المشرف يعتمد `user_type` القابل للتصعيد (C1)؛ الخطة تطلب حذف المستندات بعد القرار — غير منفّذ |
| NFR-3.1 | توافرية 99.9% | — | — | — | — | — | ❌ | لا Sentry/Uptime/PostHog في الكود |
| NFR-3.2 | Offline cache للإعلانات المحفوظة | — | — | — | — | — | ❌ | لا Hive/sqflite/cache |
| NFR-4.1 | عربية كاملة RTL + خط Cairo | — | — | خطوط Cairo + `easy_localization` (`ar-EG.json`) | `dir="rtl"` | ❌ | ⚠️ | 104 نص عربي hardcoded في `Text('…')` مقابل 113 استخدام `.tr()` |
| NFR-4.2 | Android 8+ / iOS 13+ | — | — | iOS target 13.0؛ Android `flutter.minSdkVersion` | — | ❌ | ⚠️ | لا اختبار على أجهزة |

**الإجمالي:** ✅ 0 — ⚠️ 12 — ❌ 6 — 🐛 10

---

## 5. ملاحظات إضافية حسب الطبقة (مختصرة)

**DB:** FKs بتعارض `NOT NULL` + `ON DELETE SET NULL` في `audit_logs.actor_id` و`ad_moderation_log.moderator_id`؛ `users_insert_trigger WITH CHECK (true)` يسمح لأي دور بإدراج صفوف في `users`؛ سياستان متداخلتان لـ `user_verifications` (sprint1 + sprint10)؛ نموذجان متعارضان للأدوار (`user_type` مقابل `role_id`)؛ لا pgTAP.

**Edge Functions:** CORS `*` في كل الدوال؛ رسائل الخطأ الداخلية (رسائل DB) تُعاد للعميل؛ `ai-content-review` و`analyze-ad-image` و`notify-*` بلا تحقق هوية داخلي (فقط `verify_jwt` الافتراضي الذي يقبل مفتاح `anon` العام) → استهلاك رصيد Anthropic من أي شخص؛ نص الإعلان يُدرج مباشرة في الـ prompt (prompt injection)؛ مقارنة HMAC غير ثابتة الزمن؛ `request-otp` يسجّل رقم الهاتف في `metadata`؛ `create-ad` يتحقق من `temp_draft_id` بدون ربطه بالمستخدم.

**Flutter:** لا توجد طبقة data/domain ولا Repositories — استعلامات Supabase مباشرة داخل الـ providers والشاشات (مخالف لـ `docs/ENGINEERING_STANDARDS.md` Rule 4.1)؛ شاشة الإشعارات (`notifications_screen.dart`) وشاشة أداء الإعلان (`ad_performance_screen.dart`) فارغتان (placeholder)؛ الـ router لا يعيد التوجيه حسب KYC ولا إكمال الملف (`app_router.dart:263-285`)؛ تسجيل FCM token وتحديثه وحذفه عند الخروج موجود (`push_notification_service.dart:65-108`, `auth_provider.dart:164`) لكن بلا معالجة للتوكنات المنتهية على الخادم.

**Admin:** زر تسجيل الخروج بلا handler (`layout.tsx:45`)؛ 2FA محاكاة — الرمز لا يُتحقق منه (`login/page.tsx:33-36`)؛ إحصائيات المدفوعات تجمع كل الصفوف في الذاكرة.

**CI:** يشغّل Gitleaks + Flutter فقط؛ `flutter analyze` سيفشل حالياً؛ لا CI للوحة ولا للدوال ولا للقاعدة.

**شجرة العمل:** توجد تعديلات غير مُرسَلة ليست مني (نقل 7 ملفات SQL إلى `archive/`، نقل checklists إلى `docs/internal/`، تبديل مشروع Supabase، تعديلات auth/post_ad، placeholders مفاتيح Maps، `build_app.bat`، `deploy_functions.bat`). لم ألمسها.

---

## 6. خطة الإصلاح المرتّبة (للمرحلة الثالثة — لم يبدأ أي منها)

### 🔴 حرج
| ID | المهمة | المتطلب | يحتاج موافقتك؟ |
|---|---|---|---|
| SEC-01 | تأسيس `supabase/migrations/` بـ baseline مطابق لما هو مطبَّق فعلاً على المشروع (بعد `supabase db dump`)، وإيقاف استخدام `wasla-schema.sql` (`DROP SCHEMA`) | الكل | **نعم** — تغيير معماري، ويحتاج وصولاً للمشروع الحي |
| SEC-02 | إغلاق تصعيد الصلاحيات: منع تعديل `user_type/is_id_verified/trust_score/status` من العميل (trigger أو column grants) | NFR-2.2, FR-1.4 | لا |
| SEC-03 | `REVOKE EXECUTE … FROM anon, authenticated` على دوال الإشراف و`create_ad_transaction`، واشتقاق هوية المشرف من `auth.uid()` مع فحص `is_moderator()`، وإضافة `SET search_path` | FR-6.x | لا |
| SEC-04 | إصلاح سياسات `user_credits`, `user_verifications`, `users` SELECT (إخفاء phone/email)، وتفعيل RLS على الجداول الـ 12 | NFR-2.2 | **نعم** إن كان إخفاء الهاتف يكسر شاشات قائمة |
| PAY-01 | تسعير من الخادم فقط (من `subscription_plans` / `app_configs`)، مقارنة `amount_cents` في الـ webhook، تحديث ذرّي `WHERE status='pending'`، معالجة `credit_purchase`، اختبارات HMAC صحيح/خاطئ | FR-5.x | **نعم** — تغيير منطق الدفع |
| ADM-01 | جعل اللوحة تُبنى (tsconfig, lockfile, eslint, tailwind)، ترقية Next.js لإصدار مُرقَّع، فحص admin على السيرفر في كل صفحة وServer Action بعميل جلسة (`@supabase/ssr`)، حماية `getSignedUrl` | FR-6.x, NFR-2.2 | **نعم** — ترقية مكتبة أساسية |
| DB-01 | إصلاح اعتماد الإعلانات: نقل الإشعار من trigger `pg_net` إلى استدعاء صريح أو Database Webhook مع إعداد عبر Vault | FR-3.3, FR-6.1 | **نعم** — قرار معماري |

### 🟠 عالي
| ID | المهمة | المتطلب |
|---|---|---|
| ADW-01 | Post Ad Wizard: seed حقول لكل الأقسام في migration + وراثة حقول الأب (RPC أو استعلام `category_id IN (sub, parent)`) + تحقق إلزامية ونوع الحقول في `create-ad` + اختبار لكل قسم | FR-3.2 |
| KYC-01 | `moderate_kyc` يضبط `is_id_verified`، توحيد اسم الـ bucket، حذف المستندات بعد القرار، تشفير الرقم القومي | FR-1.4, NFR-2.2 |
| DEL-01 | حذف الحساب: جدول `account_deletion_requests` + إصلاح FKs (`audit_logs`, `ad_moderation_log`) + مهمة hard-delete بعد 30 يوماً | Security plan §6 |
| SRCH-01 | تطبيق نص البحث فعلياً (`advanced_search_ads`) وإصلاح `normalize_arabic` | FR-2.2 |
| FCM-01 | إرسال FCM فعلي (HTTP v1) من الخادم، حذف التوكنات المنتهية، تحقق هوية دوال `notify-*` | FR-4.2, FR-6.1 |
| AI-01 | تحديث نماذج Claude، تحقق هوية + rate limit على `ai-content-review`، فصل نص الإعلان عن التعليمات، تسجيل القرار وسببه | — |
| OTP-01 | إزالة الرجوع المباشر لـ `signInWithOtp`، حد لكل IP، إزالة رقم الاختبار من رسائل المستخدم | FR-1.1 |
| QA-01 | `flutter analyze` بلا مشاكل، `deno lint` بلا مشاكل، CI للوحة والدوال والقاعدة | — |

### 🟡 متوسط (متطلبات ناقصة)
FR-1.2 (Facebook)، FR-1.3 (اختيار المدينة)، FR-1.4 (سيلفي + مطابقة وجه)، FR-2.1 (Feed بالموقع)، FR-2.3 (فلتر الحي والتاريخ)، FR-2.4 (خريطة + clusters)، FR-5.3 (فرض حدود الباقات)، NFR-1.2 (WebP على الخادم)، NFR-3.2 (offline cache)، شاشة الإشعارات، شاشة أداء الإعلان، طبقة Repositories، اختبارات pgTAP لكل جدول، integration test لرحلة النشر.

### 🟢 منخفض
نقل النصوص الـ hardcoded إلى ملفات الترجمة، `autoDispose` و`select` للـ providers، تنظيف ملفات SQL القديمة/البديلة، تحديث README.

---

## 7. قرارات تحتاج موافقتك قبل البدء

1. **أيّ مشروع Supabase هو Production وأيّها Staging** (`fgvjjtbtlzjpzaqypzmz` أم `bizikadaucsyevdoagmm`)؟ وهل يمكنني الحصول على `supabase db dump` للمشروع الحي؟ بدونه لا أستطيع بناء baseline migration مطابق للواقع، لأن الملفات في الريبو لا تُطبَّق بشكل نظيف.
2. **التعديلات غير المُرسَلة في شجرة العمل:** هل أُرسلها كما هي في commit منفصل قبل البدء، أم تراجعها أنت أولاً؟
3. **المرجع الرسمي للمتطلبات:** الـ SRS الموجود (28 متطلباً، إعلانات عامة) أم وثيقة أخرى بـ 56 متطلباً غير موجودة في الريبو؟
4. **مصدر تسعير الـ Boost والاشتراكات** (PAY-01) وترقية Next.js (ADM-01) والانتقال من trigger `pg_net` (DB-01) — كلها تقع ضمن ما طلبت أن أسألك عنه.
5. **مزوّد مطابقة الوجه لـ KYC** (FR-1.4): الـ SRS يطلبه ولا يوجد أي تنفيذ أو اختيار مزوّد.

## 8. ما لم يُنفَّذ في هذه المرحلة
- `supabase start` / `db reset` بالـ CLI (غير مثبّت، ولا migrations لتطبيقها) — استُبدل بحاوية Postgres كما في §3.4.
- `flutter build apk --release` وبناء iOS.
- أي اختبار end-to-end أو اختبار على مشروع Supabase حي أو على Paymob Sandbox.
- اختبارات RLS لكل جدول بشكل منهجي — نُفِّذت 14 probe مستهدفة فقط.
