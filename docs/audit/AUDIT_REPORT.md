# تقرير التدقيق — المرحلة الأولى (الاستكشاف والجرد)

- **التاريخ:** 2026-10-26
- **الفرع:** `develop` @ `333e1e7` + تعديلات غير مُرسَلة (uncommitted) في شجرة العمل
- **النطاق:** §1–§8 = المرحلة الأولى (قراءة فقط). §9 = المرحلة الثالثة، البنود 🔴 (أ)(ب)(ج) على الفرع `fix/audit`.
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
| FR-1.1 | تسجيل بالهاتف + OTP 6 أرقام | Supabase Auth (`[auth.sms]` و`[auth.rate_limit]` و`[auth.hook.send_sms]`) | `send-sms-hook` (Standard Webhooks، `SmsProvider`، Twilio للتجربة) | `auth_provider.dart`، `otp_screen.dart` | — | Flutter 3 + Deno 10 + تكامل Auth حقيقي (5 خطوات) | ⚠️ | §14 و§17: الحد بيفرضه Auth، والإرسال بيعدّي على hook موقّع، والفشل مقفول، ومفيش OTP في أي سجل. متبقٍ: تجربة مزوّد حقيقي (مستني الأسرار)، واختيار المزوّد المحلي للإنتاج |
| FR-1.2 | تسجيل اجتماعي Google + Facebook | — | — | Google فقط `auth_provider.dart:147` | — | ❌ | ⚠️ | Facebook: 0 نتائج بحث |
| FR-1.3 | إعداد الملف (مدينة، اسم، صورة) | `users.city_id`، bucket `avatars` | — | `profile_setup_screen.dart` (محافظة ← مدينة) | — | pgTAP 14 + 20 + Storage 9 + widget 2 | ⚠️ | §18: اختيار المدينة اتنفّذ. متبقٍ: التجربة على جهاز |
| FR-1.4 | KYC: وجه/ظهر + سيلفي + مطابقة + شارة | `user_verifications` (+`decided_at`, `documents_deleted_at`) | `submit-kyc-request`, `purge-kyc-documents`, `moderate_kyc` | `verification_screen.dart` | `kyc/` | pgTAP 18 + تكامل KYC محلي | ⚠️ | مُصلح (§14): الاعتماد يضبط شارة ✓ الظاهرة للكل، والمستندات تُحذف بعد 7 أيام من الاعتماد و30 يوماً من الرفض. الرقم القومي مايتخزنش: آخر 4 أرقام + HMAC، ونفس الرقم مايتقبلش على حسابين (N14). متبقٍ: السيلفي (🟡 #20)، ولا مطابقة آلية حسب قرارك |
| FR-2.1 | Feed حسب موقع GPS | `location_point` (elite_v3) | — | — | — | ❌ | ❌ | لا استخدام لـ `geolocator` في `lib/` |
| FR-2.2 | بحث نصي عربي بالمرادفات والأخطاء | `normalize_arabic`, `search_ads()`, فهرس trigram | — | `ads_provider.dart` | — | pgTAP 17 + Flutter | ⚠️ | مُصلح (§11): توحيد الحروف، بحث بالبادئة، وتسامح مع الأخطاء الإملائية. متبقٍ: المرادفات غير منفّذة |
| FR-2.3 | فلاتر: قسم، سعر، مدينة، حي، نوع، تاريخ | `search_ads(p_district_id, p_posted_within_days)` | — | `explore_screen.dart` (شيت الفلاتر) | — | pgTAP 21 + widget 2 + Flutter | ⚠️ | §18: الحي والتاريخ والمدينة في الشيت، والفلاتر مابقتش تمسح البحث. متبقٍ: **فلتر القسم مش بيوصل للبحث** (N19) |
| FR-2.4 | عرض خريطة مع Clusters | — | — | — | — | ❌ | ❌ | `GoogleMap` يُستخدم فقط لاختيار الموقع (`location_price_screen.dart:504`)؛ مفتاح Maps placeholder في `AndroidManifest.xml`/`AppDelegate.swift` (تعديل غير مُرسَل) |
| FR-3.1 | معالج 5 خطوات، حتى 8 صور | `ad_media` | `create-ad` | `post_ad/` (6 شاشات) | — | `post_ad_wizard_test.dart` | ⚠️ | حد 8 صور في العميل فقط (`add_photos_screen.dart:24`)؛ لا تحقق في الخادم؛ لا integration test |
| FR-3.2 | حقول ديناميكية حسب القسم | `category_fields`, `get_category_fields()` | `create-ad` (يتحقق من الإلزامي والقيم) | `category_fields_provider.dart` | — | pgTAP 14 + Deno 5 | ⚠️ | مُصلح (§10): كل الأقسام الفرعية لها حقول. متبقٍ: تجربة المعالج على جهاز فعلي |
| FR-3.3 | معلَّق → مراجعة → نشط 30 يوماً | `expire-ads` cron | `moderate_ad` | `my_ads_screen.dart` | `ads/` | pgTAP 05 | ⚠️ | الاعتماد يعمل الآن (§10). متبقٍ: `expires_at` يُحسب من الإنشاء لا من الاعتماد، ولا يوجد تمديد |
| FR-4.1 | مفضلة + ملاحظات | `favorites.notes` | — | `saved_screen.dart:79-163` | — | ❌ | ⚠️ | العرض موجود؛ لم أجد تحريراً للملاحظة؛ غير مختبر |
| FR-4.2 | بحث محفوظ + إشعار فوري | `saved_searches` (تحقق + حد 20)، `notifications`، `notifications_outbox` | `dispatch-notifications` (FCM v1) | `explore_screen.dart` (احفظ البحث)، `saved_screen.dart`، `notifications_screen.dart` | — | pgTAP 18 + 19 + 21 + Flutter + Deno | ⚠️ | §18: الحفظ من شاشة البحث، والمطابقة بقت زي البحث (تطبيع عربي)، ومركز إشعارات بشارة حية. متبقٍ: FCM حقيقي (مستني service account) |
| FR-4.3 | تسجيل نقرات الاتصال/واتساب | `contact_logs` | — | `ads_provider.dart:253` | — | ❌ | ⚠️ | سياسة الإدراج `WITH CHECK (TRUE)` (`wasla-schema.sql:896`) → تزوير/إغراق الإحصائيات |
| FR-4.4 | تقييم 1-5 + رد واحد للمعلن | `reviews`, `review_responses` | — | `reviews_controller.dart` | — | pgTAP 13 | ⚠️ | مُصلح (§11): الإدراج يعمل وصيغة الثقة موحّدة. متبقٍ: N12 (المقيِّم يقدر يعدّل حالة تقييمه) |
| FR-5.1 | Paymob (بطاقة، فوري، محفظة) | `transactions`, `payment_packages`, `fulfill_payment()` | `create-payment`, `payment-webhook` | `payment_webview_screen.dart` | — | pgTAP 26 + Deno 23 | ⚠️ | 🔴(ب) مُصلح ومختبر محلياً (§9). متبقٍ: تجربة Paymob Sandbox فعلية، وتكامل فوري/المحفظة (يوجد integration بطاقة واحد فقط) |
| FR-5.2 | Featured / Urgent / Bump | `ad_boosts`, `payment_packages`, cron | `fulfill_payment()` | `boost_ad_screen.dart`, `boost_controller.dart` | — | pgTAP 26 | ⚠️ | النوع والمدة من الباقة على السيرفر (§9). متبقٍ: Sandbox + انتهاء الصلاحية عبر cron غير مختبر |
| FR-5.3 | اشتراكات تجارية بحدود أعلى | `subscription_plans` (RLS معطّل) | webhook | `subscription_screen.dart` | — | `monetization_test.dart` | 🐛 | مدة ثابتة 30 يوماً؛ لا يوجد فرض لحدود الإعلانات في أي مكان؛ أي زائر يعدّل جدول الخطط |
| FR-6.1 | مراجعة الإعلانات + سبب + إشعار | `ad_moderation_log` | `moderate_ad` + outbox | — | `ads/` | pgTAP + Vitest | ⚠️ | الاعتماد/الرفض والإشعار يعملان (§10). متبقٍ: تجربة اللوحة يدوياً من المتصفح |
| FR-6.2 | بلاغات + حظر | `reports`, `audit_logs` | `handle_report` | بلاغ من `ad_detail_screen.dart:532` | `reports/`, `users/` | Vitest 20 + تكامل 3 | ⚠️ | الحظر والتعليق يمنعان تسجيل الدخول فعلياً عبر Auth (§12). متبقٍ: إعلانات المحظور تبقى ظاهرة، وصلاحية الـ access token الحالي تستمر حتى ساعة، ومسار البلاغات لم يُجرَّب يدوياً في اللوحة |
| NFR-1.1 | الصفحة الرئيسية ≤ 2 ثانية | فهارس | — | pagination موجود | — | `scripts/wasla-load-test.js` لم يُشغَّل | ❌ | لا قياس |
| NFR-1.2 | ضغط تلقائي وتحويل WebP على السيرفر | — | — | `imageQuality: 80, maxWidth: 1600` على العميل | — | ❌ | ❌ | `grep webp` = 0 |
| NFR-2.1 | HTTPS/TLS | — | Supabase/Paymob https | — | — | ❌ | ⚠️ | الافتراضي https؛ لم يُتحقق من إعدادات الإنتاج |
| NFR-2.2 | مستندات الهوية خاصة + روابط مؤقتة للمشرف | bucket خاص `id-documents` | `purge-kyc-documents` (cron يومي) | — | `getKycDocumentUrl` (staff + aal2) | Vitest + pgTAP 18 + تكامل KYC | ⚠️ | 🔴(ج) و§14: الروابط تصدر من اللوحة فقط بعد aal2، وحُذفت `get-kyc-document` لأنها كانت تتجاوز الـ MFA، والمستندات تُحذف بعد القرار، والرقم القومي مايتخزنش (N14). متبقٍ: تجربة اللوحة يدوياً من المتصفح |
| NFR-3.1 | توافرية 99.9% | — | — | — | — | — | ❌ | لا Sentry/Uptime/PostHog في الكود |
| NFR-3.2 | Offline cache للإعلانات المحفوظة | — | — | — | — | — | ❌ | لا Hive/sqflite/cache |
| NFR-4.1 | عربية كاملة RTL + خط Cairo | — | — | خطوط Cairo + `easy_localization` (`ar-EG.json`) | `dir="rtl"` | ❌ | ⚠️ | 104 نص عربي hardcoded في `Text('…')` مقابل 113 استخدام `.tr()` |
| NFR-4.2 | Android 8+ / iOS 13+ | — | — | iOS target 13.0؛ Android `flutter.minSdkVersion` | — | ❌ | ⚠️ | لا اختبار على أجهزة |

**الإجمالي (محدَّث بعد §18):** ✅ 0 — ⚠️ 21 — ❌ 6 — 🐛 1 (FR-5.3 الاشتراكات)

> تصحيح: إجمالي §12 كان بيعدّ FR-1.4 بس كـ 🐛 وناسي FR-5.3، فكان فيه ⚠️ زيادة واحد. العدّ هنا محسوب من صفوف الجدول نفسها.

> لا يوجد متطلب بحالة ✅ بعد. الإصلاحات مُتحقَّق منها على قاعدة البيانات والسيرفر وAPIs المحلية، لكن لم يُجرَّب أي متطلب end-to-end على جهاز أو على Paymob Sandbox أو FCM حقيقي، وهذا شرط ✅ حسب تعريف الاكتمال.

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

---

## 9. المرحلة الثالثة — البنود 🔴 (أ)(ب)(ج)

**الفروع:** `wip-before-audit` (`5d508bc`: التعديلات غير المُرسَلة كما هي) ← `fix/audit`.
**تحفّظ مهم:** لم يصل الـ schema dump للإنتاج بعد، فلا يوجد baseline migration. الـ migrations الجديدة مكتوبة بحيث تتحمّل اختلاف أسماء السياسات والكائنات (حلقات على `pg_policy`/`pg_proc` و`to_regclass`)، واختُبرت على مخطط مُعاد بناؤه من ملفات SQL القديمة داخل حاوية مؤقتة (`LEGACY_BASELINE=1 scripts/db/run_db_tests.sh`). **يجب إعادة تشغيل الاختبارات نفسها فوق الـ baseline الحقيقي عند وصوله وقبل أي تطبيق على بيئة حية.** لم يُطبَّق شيء على أي مشروع Supabase.

### (أ) SEC — قفل صلاحيات العميل
```
المهمة: SEC-02/03/04 — RLS على كل الجداول، سحب EXECUTE من دوال الإشراف، منع تعديل الدور/التوثيق/الرصيد، إخفاء phone/email
المتطلب المرتبط: NFR-2.2, FR-1.4, FR-6.1, FR-6.2
الملفات: supabase/migrations/20261026100000_sec_client_lockdown.sql
         supabase/tests/database/01_rls_lockdown.test.sql
         frontend/mobile/wasla/lib/{shared/providers/ads_provider.dart, features/ads/screens/ad_detail_screen.dart, features/auth/providers/auth_provider.dart}
معيار القبول: كل probes المرحلة الأولى (P2, P3, P4, P8, P13, P14) تفشل بـ 42501؛ المالك يقرأ بياناته؛ service_role لا يتأثر
الاختبار: LEGACY_BASELINE=1 scripts/db/run_db_tests.sh
الدليل: قبل الـ migration: 14 من أول 15 تأكيداً فشلت (مثلاً "anon cannot read users.phone — caught: no exception")
        بعد الـ migration: 01_rls_lockdown 40/40 ok
الحالة: ✅ (على المخطط المُعاد بناؤه)
الـ commit: 1393df3
```
- القراءة العامة لـ `users` صارت أعمدة محددة فقط؛ `phone/email/user_type/status` للمالك عبر `get_my_profile()`.
- **قرار منتج نفّذته ويحتاج تأكيدك:** رقم البائع يُعطى عبر `get_ad_contact()` **لمستخدم مسجَّل فقط** (تسجيل التواصل يتم تلقائياً، ويمنع جمع الأرقام من زوار مجهولين). الزائر يُحوَّل لشاشة الدخول عند الضغط على اتصال/واتساب. يمكن فتحه للزوار إن أردت.
- دوال الـ trust score صارت `SECURITY DEFINER` لأنها تكتب في صفوف مستخدمين آخرين.

### (ب) PAY — التسعير على السيرفر
```
المهمة: PAY-01 — جدول أسعار، العميل يرسل package_id فقط، الـ webhook يتحقق من HMAC والمبلغ
المتطلب المرتبط: FR-5.1, FR-5.2, FR-5.3
الملفات: supabase/migrations/20261026110000_pay_server_side_pricing.sql
         supabase/tests/database/02_payments.test.sql
         supabase/functions/create-payment/{handler.ts, paymob.ts, index.ts, handler_test.ts}
         supabase/functions/payment-webhook/{handler.ts, index.ts, handler_test.ts}
         frontend/mobile/wasla/lib/features/profile/{providers/boost_controller.dart, providers/subscription_controller.dart, screens/subscription_screen.dart}
         frontend/mobile/wasla/test/features/profile/subscription_package_test.dart
معيار القبول: المبلغ/النوع/المدة من العميل تُتجاهل؛ دفع ناقص أو بعملة أخرى لا يفعّل شيئاً؛ الإشعار المكرر لا يفعّل مرتين؛ HMAC خاطئ أو مبلغ معدَّل بنفس HMAC = 401
الاختبار: scripts/db/run_db_tests.sh (02_payments) — deno test --no-lock create-payment payment-webhook
الدليل: 02_payments 26/26 ok — Deno 23 passed / 0 failed — HMAC مطابق لمتجه مرجعي محسوب مستقلاً بـ Python hmac/SHA-512
الحالة: ✅ محلياً — ⚠️ لم يُجرَّب على Paymob Sandbox
الـ commit: 65d7c2c
```
- `payment_packages` مُعبّأ من الأسعار الحالية: boosts من `app_configs` (30/60/100/180/40/10)، والاشتراكات الشهرية من `subscription_plans.price_monthly` (99/199/499).
- `fulfill_payment()` يقفل الصف (`FOR UPDATE`) ويُرجع `completed | failed | amount_mismatch | already_processed | not_found`. المعالجة المتزامنة محمية بقفل الصف، لكن لم أكتب اختباراً بجلستين متوازيتين.
- إصلاحات جانبية لازمة: `protect_ad_sensitive_fields` كان يمنع الـ webhook والإشراف من تعديل الإعلان (يعتمد `is_moderator()` = false لـ service_role)؛ صار يطبَّق على أدوار العميل فقط. شراء الرصيد لم يكن يضيف شيئاً وصار يعمل. الاشتراك كان يكتب رقم الخطة في عمود UUID (`reference_id`) فيفشل الإدراج.
- **لم أُضِف باقات رصيد** (`credit_purchase`): لا توجد أسعار معرّفة لها — قرار تسعير لك.

### (ج) ADM — صلاحيات الأدمن على السيرفر
```
المهمة: ADM-01 — بناء اللوحة، Next 14.2.35، فحص staff في كل صفحة وServer Action، getSignedUrl
المتطلب المرتبط: FR-6.1, FR-6.2, NFR-2.2
الملفات: frontend/admin/{lib/auth.ts, lib/supabase/server.ts, lib/supabase/browser.ts, middleware.ts,
         app/dashboard/**/{page,actions}.ts(x), app/dashboard/layout.tsx, app/login/page.tsx,
         components/KYCImagePreview.tsx, tsconfig.json, .eslintrc.json, tailwind.config.ts, postcss.config.js,
         vitest.config.ts, tests/*, package.json, package-lock.json, .gitignore}
معيار القبول: لا صفحة ولا action تعمل لغير staff؛ الدور من public.users لا من user_metadata؛ رابط مستند الهوية فقط لمسار مسجَّل على طلب توثيق، مع سجل تدقيق؛ مفتاح service_role لا يصل للمتصفح
الاختبار: cd frontend/admin && npm test && npx tsc --noEmit && npx next lint && npx next build
الدليل: Vitest 17/17 — tsc exit 0 — lint exit 0 (تحذيران في كود قديم) — next build exit 0
        بناء بقيمة canary للمفتاح: 0 ظهور في .next/static (مقابل ظهور مفتاح anon كما هو متوقع)
الحالة: ✅
الـ commit: d1356aa
```
- `getSignedUrl(path)` حُذفت؛ البديل `getKycDocumentUrl(verificationId, side)` لا يقبل مساراً من العميل، ويستخدم bucket `id-documents` الصحيح (كانت `kyc-documents` فلم تكن تعمل أصلاً)، صلاحية 300 ثانية، ويُسجَّل في `audit_logs`.
- المشرف لا يغيّر حالة حساب admin/moderator؛ الإعدادات للـ admin فقط؛ لا أحد يغيّر حالة حسابه.
- صفحة الدخول كانت تستخدم عميلاً يخزّن الجلسة في localStorage فلا يراها السيرفر؛ صارت cookies.

### نتائج جديدة اكتُشفت أثناء التنفيذ (لم تُصلح — خارج نطاق 🔴)
| # | المشكلة | الدليل | الأولوية المقترحة |
|---|---|---|---|
| N1 | كل إدراج تقييم يفشل: `refresh_user_trust_score()` يقرأ `NEW.user_id` على جدول `reviews` | خطأ `42703: record "new" has no field "user_id"` أثناء اختبار (أ) | 🟠 |
| N2 | "2FA" في دخول اللوحة شكلي: الرمز لا يُتحقق منه أبداً (`login/page.tsx`) | قراءة الكود | 🟠 — يحتاج قرارك: Supabase MFA (TOTP) أم إزالة الخطوة |
| N3 | إعدادات اللوحة تكتب في `config_key/config_value` بينما الجدول `key/value` | `settings/actions.ts` مقابل `wasla-schema.sql:535` | 🟠 |
| N4 | ~~`banned` ليست قيمة في الـ enum~~ (**تصحيح:** القيمة موجودة، أضافها `sprint8_setup.sql`). المشكلة الحقيقية إن الحظر ماكانش بيمنع تسجيل الدخول، واتصلحت في §12 | — | مُصلح |
| N5 | قراءة باقات الـ boost في التطبيق كانت تفشل (`value as String` على JSONB رقمي) — استُبدلت ضمن (ب) | `boost_controller.dart` القديم | مُصلح |
| N6 | `deno lint`: بقي 10 مشاكل `no-explicit-any` في دوال لم تُلمس | `deno lint` | 🟢 |

### نتائج كل الحزم بعد (أ)(ب)(ج)
| الحزمة | النتيجة |
|---|---|
| DB (pgTAP) | 66/66 ok — `LEGACY_BASELINE=1 scripts/db/run_db_tests.sh` → `RESULT: PASS` |
| Edge Functions | `deno test` 23/23 — `deno check` للدالتين المعدّلتين exit 0 — `deno lint` 10 مشاكل (كانت 17) |
| Admin | Vitest 17/17 — tsc 0 — lint 0 — build 0 |
| Flutter | `flutter test` 43/43 (كانت 41) — `flutter analyze` نفس الـ 15 مشكلة السابقة، لا جديد |

---

## 10. المرحلة الثالثة (تابع): القرارات الأربعة، ثم 🟠 (أ)(ب)

**نقطة البداية:** التطبيق لم يُطلق ولا توجد بيانات. المرجع الآن هو `supabase/migrations/` فقط. Production سيكون مشروعاً جديداً.

### الـ baseline: `supabase db reset` من الصفر
```
الملفات: supabase/migrations/0000_baseline.sql, supabase/config.toml, scripts/db/*
الاختبار: npx supabase@2.120.0 db reset && npx supabase@2.120.0 test db
الدليل: 6 migrations طُبّقت بلا أخطاء؛ Files=5, Tests=129, Result: PASS
        بيانات مرجعية بعد الـ reset: 27 محافظة، 58 مدينة، 53 حياً، 39 قسماً، 4 خطط، 9 باقات دفع، 2 bucket، 7 cron jobs
الـ commit: 3ad7a62
```
الـ baseline ناتج عن pg_dump للمخطط الذي تبنيه الملفات القديمة، بدون `DROP SCHEMA`. يتضمن: البيانات المرجعية، trigger على `auth.users`، الـ buckets وسياساتها، ومهام cron. أبقيته مطابقاً للواقع، بعيوبه، والإصلاحات في migrations لاحقة.

### القرارات الأربعة
| البند | الـ commit | الدليل |
|---|---|---|
| `reveal_seller_phone(ad_id)` للمسجّلين فقط. الحد 20 إعلاناً مختلفاً/ساعة و100/يوم (من `app_configs`)، وتكرار نفس الإعلان خلال 24 ساعة لا يُحسب. كل طلب يُسجَّل في `phone_reveal_log` (`revealed` / `rate_limited` / `not_available`). حلّت محل `get_ad_contact` | `c1f685a` | pgTAP 20/20، والاختبار فشل أولاً. Flutter 46/46 |
| MFA بـ TOTP إجباري لكل staff. الفحص على السيرفر يتطلب `aal2` في كل صفحة وaction، وmiddleware يطبّق نفس القاعدة أولاً. حُذفت الخطوة الشكلية | `a912a24` | Vitest 22/22، منها 3 على GoTrue محلي حقيقي: enroll → aal2، دخول جديد → aal1، رمز خاطئ يُرفض |
| `credit_purchase`: لا توجد واجهة في التطبيق أصلاً. أضفت رفضاً على السيرفر في `create-payment` | `77490da` | Deno 12/12 |

### 🟠(أ) Post Ad Wizard
```
المهمة: الحقول الديناميكية لكل الأقسام الفرعية + "خدمات" و"سلع"، وتصحيح الاستعلام
المتطلب المرتبط: FR-3.2, FR-3.1
الملفات: supabase/migrations/20261027100000_category_fields_seed.sql, supabase/tests/database/04_category_fields.test.sql,
         supabase/functions/create-ad/{fields.ts, fields_test.ts, index.ts},
         frontend/mobile/wasla/lib/features/post_ad/providers/category_fields_provider.dart
معيار القبول: كل قسم فرعي نشط له حقول؛ الحقول المشتركة من القسم الأب تظهر أولاً؛ create-ad يرفض الحقول الإلزامية الناقصة والقيم خارج الخيارات
الاختبار: supabase test db — deno test create-ad
الدليل: قبل الإصلاح الاختبار فشل (الدالة غير موجودة، و34 قسماً فرعياً بلا حقول).
        بعده: 14/14. واستدعاء REST حقيقي بمفتاح anon لـ get_category_fields(شقق للإيجار) أرجع 6 حقول:
        area_sqm من القسم الأب أولاً، ثم rooms, bathrooms, floor, furnished, rent_period
الحالة: ✅ في قاعدة البيانات والسيرفر، ⚠️ لم يُجرَّب على جهاز
الـ commit: 87d2091
```

### 🟠(ب) notifications_outbox + FCM
```
المهمة: استبدال triggers الـ pg_net بـ outbox + Edge Function، وتفعيل إرسال FCM فعلياً
المتطلب المرتبط: FR-3.3, FR-4.2, FR-6.1
الملفات: supabase/migrations/20261027110000_notifications_outbox.sql, supabase/tests/database/05_notifications.test.sql,
         supabase/functions/dispatch-notifications/*, حذف notify-ad-status و notify-watchlist-match
معيار القبول: الاعتماد والرفض لا يستدعيان الشبكة داخل الـ transaction؛ فشل الإشعار لا يلغي العملية؛ إرسال حقيقي عبر FCM HTTP v1؛ التوكنات الميتة تُعطَّل؛ إعادة المحاولة مع backoff
الاختبار: supabase test db — deno test — deno test --no-check --allow-env --allow-net dispatch-notifications/integration.local.ts
الدليل: قبل الإصلاح الاختبار فشل: "approving an ad succeeds" not ok.
        بعده: 29/29، ومنها اعتماد ينجح والـ outbox مُعطَّل عمداً (إعادة تسمية الجدول).
        Deno 10/10: توقيع JWT من نوع RS256 يُتحقق منه بالمفتاح العام المقابل، وشكل رسالة HTTP v1، وحالتا UNREGISTERED/404.
        تكامل على Supabase المحلي: اعتماد → outbox → dispatcher → sent، والتوكن الميت صار is_active=false
الحالة: ✅ محلياً، ⚠️ لم يُرسَل لـ FCM حقيقي
الـ commit: fb88070
```
- الـ cron يستدعي الـ dispatcher كل دقيقة عبر `pg_net`. هذا هو الاستدعاء الشبكي الوحيد المتبقي، ويحدث خارج أي transaction للمستخدم. يقرأ `project_url` و`service_role_key` من Vault، وتعليمات الإعداد في `docs/wasla_production_migration_plan.md`.
- تفضيلات المستخدم محترمة: إيقاف `ad_status_updates` أو `watchlist_matches` يمنع الـ push فقط، والإشعار داخل التطبيق يُسجَّل دائماً.

### نتائج كل الحزم بعد §10
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | `db reset` بـ 6 migrations، و`test db` 129/129 |
| Docker runner | 129/129 |
| Edge Functions | `deno test` 39/39، وتكامل 1/1. `deno lint` فيه 8 مشاكل، كلها `any` في دوال لم تُلمس |
| Admin | Vitest 22/22، tsc وlint وbuild كلها exit 0 |
| Flutter | 46/46، و`analyze` فيه نفس الـ 15 مشكلة القديمة |

### نتائج جديدة
| # | المشكلة | الدليل | الأولوية |
|---|---|---|---|
| N7 | **أي مستخدم مسجَّل يقدر يعدّل أو يحذف أي صورة إعلان.** سياسات `Auth Users Update/Delete/Upload` على bucket `ads` تفحص `auth.role()='authenticated'` فقط، بدون مجلد المالك | `0000_baseline.sql` (سياسات storage.objects) | 🔴 |
| N8 | مهمة cron `cleanup-stale-transactions` تضع `status='expired'` وهي ليست قيمة في `transaction_status_enum`، فتفشل كل ساعة | `cron.job` | 🟠 |
| N9 | bucket `avatars` غير موجود، فرفع الصورة الشخصية يفشل (FR-1.3) | `storage.buckets` = `ads`, `id-documents` فقط | 🟠 |
| N10 | لا توجد واجهة لحفظ بحث (FR-4.2)، وشاشة الإشعارات فارغة رغم أن جدول `notifications` يمتلئ الآن | `saved_searches` لا يُكتب من التطبيق؛ `notifications_screen.dart` | 🟡 |
| N11 | الإرسال الفعلي لـ FCM لم يُجرَّب لعدم توفر Firebase service account | — | يحتاج `FIREBASE_SERVICE_ACCOUNT` |

---

## 11. N7، cron، الصور الشخصية، و🟠 (ج)(د)(هـ)

كل بند في commit منفصل. في كل بند كتبت الاختبار وشغّلته فشل أولاً، وبعدين الإصلاح.

| البند | الـ commit | الفشل قبل الإصلاح | بعد الإصلاح |
|---|---|---|---|
| **N7** صور الإعلانات | `a73ef3f` | pgTAP: مستخدم B نقل صورة A، ورفع ملفات في مجلد A وخارج أي مجلد. Storage API: B كتب فوق صورة A وحذفها، وملف نصي وملف أكبر من 5MB اتقبلوا | pgTAP 13/13، Storage API 9/9 خطوات |
| مهمة cron | `c9ae97c` | `22P02 invalid input value for enum ... "expired"` | كل أوامر cron الـ 8 بتتنفذ من `cron.job` بدون أخطاء، 12/12 |
| bucket الصور الشخصية | `c9011a2` | الـ bucket غير موجود | pgTAP 14/14، Storage API 9/9 خطوات |
| 🟠(ج) التقييمات | `b5e7834` | `42703 NEW.user_id`، triggerان للثقة، والدرجة ثابتة على 0 | 13/13 |
| 🟠(د) حذف الحساب | `66ebf98` | الدالة غير موجودة، وحذف أي مشرف كان مستحيلاً (P12 في المرحلة الأولى) | pgTAP 26/26، Deno 3/3، تكامل كامل 1/1 |
| 🟠(هـ) البحث | `9a3413d` | دالة البحث غير موجودة، ونص البحث مش بيتطبّق أصلاً | pgTAP 17/17، Flutter 2/2، واستدعاء REST حقيقي |

**تفاصيل تستحق الانتباه:**
- **N7:**
  - السياسات القديمة الثلاث على bucket `ads` اتحذفت كلها. الكتابة والتعديل والحذف بقت مشروطة بـ `storage.foldername(name)[1] = auth.uid()`.
  - الأنواع المسموحة JPEG/PNG/WebP، والحد الأقصى 5MB.
  - `create-ad` بقى يرفض أي رابط صورة من خارج مجلد المستخدم، ويرفض أكثر من 8 صور (Deno 10/10).
  - شلت من المعالج رابط `mock.wasla.com` اللي كان بيظهر كنجاح وهمي لما المستخدم مش مسجّل.
- **الصور الشخصية:** المسار القديم في التطبيق `avatars/{uid}/...` كان مخالفاً لقاعدة المجلد، فاتغيّر إلى `{uid}/avatar.jpg`. الحد 2MB.
- **(ج):** ظهر في الاختبار bugان إضافيان واتصلحا:
  - التوثيق ماكانش بيضيف الـ 30 نقطة أبداً، لأن الـ trigger كان بيقرأ القيمة القديمة.
  - فحص أهلية التقييم كان بيعتمد على مين اللي بيسأل، لأن RLS كانت بتخفي عنه سجلات تواصل الآخرين.
- **(د):** اختبار التكامل كشف إن `banned_until = 'infinity'` بيخلّي GoTrue يفشل في تحميل المستخدم ("Database error loading user")، فالحذف النهائي كان هيفشل دائماً. استبدلته بتاريخ بعيد. التكامل يثبت دلوقتي:
  - تسجيل الدخول بيترفض برسالة "banned".
  - الحذف بعد 30 يوماً بيمسح 3 ملفات، والمستخدم من Auth، والملف الشخصي.
- **(هـ):**
  - حد التشابه 0.5. خطأ إملائي من كلمتين حقق 0.69، وكلمة واحدة 0.50، والكلمات غير المرتبطة 0.14.
  - القسم الرئيسي بقى يشمل أقسامه الفرعية، وده يصلح كمان مشكلة فلتر القسم في FR-2.3.

### نتائج كل الحزم بعد §11
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | `db reset` بـ 12 migration، و`test db` 224/224 |
| Docker runner | 224/224 |
| Edge Functions | `deno test` 47/47. تكامل: dispatcher 1/1، purge 1/1، storage 2/2 (18 خطوة). `deno lint` فيه 8 مشاكل، كلها في دوال لم تُلمس |
| Admin | Vitest 22/22 |
| Flutter | 49/49، و`analyze` فيه نفس الـ 15 مشكلة القديمة |

### نتائج وقرارات جديدة
| # | البند | الأولوية |
|---|---|---|
| N12 | سياسة `reviews_update_own` بتسمح للمقيِّم يعدّل أي عمود في تقييمه، ومنها `status`. يعني يقدر يرجّع تقييماً أخفاه المشرف. اكتشفته بقراءة الكود ولم أختبره | 🟠 |
| D1 | الحذف النهائي بيمسح معاملات الدفع بسبب `ON DELETE CASCADE`. **قرار احتفاظ بالسجلات المالية يحتاج موافقتك**: حذف، أو إخفاء الهوية مع الاحتفاظ بالمعاملة | قرار |
| 🟡 | واجهة حفظ البحث (FR-4.2)، وشاشة الإشعارات داخل التطبيق | 🟡 |
| متبقٍ من 🟠 | (و): إعدادات اللوحة (`config_key`) وقيمة الحظر (enum) | 🟠 التالي |

---

## 12. الاحتفاظ بالمعاملات، N12، و🟠(و): اكتمال 🟠

| البند | الـ commit | الفشل قبل الإصلاح | بعد الإصلاح |
|---|---|---|---|
| الاحتفاظ بمعاملات الدفع مع إزالة الهوية | `efd45a2` | حذف المستخدم حذف معاملتيه | pgTAP 14/14، والحذف الكامل عبر Auth API الحقيقي يحتفظ بالمعاملة مجهولة الهوية |
| N12 تعديل التقييمات | `a848da5` | تحديث بدون شرط WHERE رجّع تقييماً مخفياً وغيّر نصه، والمقيِّم نقل تقييمه لبائع آخر وغيّر تاريخه وفصله عن الإعلان | 12/12 |
| 🟠(و) الإعدادات والحظر | `53e95a2` | الإعداد لم يُحفظ، والمحظور والمعلّق قدرا يسجّلوا دخول | تكامل حقيقي 3/3، وVitest 26/26 |

- **الاحتفاظ:**
  - `transactions.user_id` بقى `SET NULL`.
  - trigger قبل حذف المستخدم بيمسح مرجع الإعلان، وبيقلّص الـ metadata لقائمة مسموحة.
  - القرار ومدة الاحتفاظ المقترحة (5 سنوات، تحتاج تأكيداً قانونياً) مسجّلان في `docs/wasla_security_privacy_plan.md` §6 وفي production plan.
  - **المحو الآلي بعد انتهاء المدة غير منفّذ بعد.**
- **N12:** التحليل الأول كان ناقصاً. الثغرة الأخطر كانت نقل التقييم لبائع آخر بدون شرط التواصل. الإصلاح:
  - الـ column privileges بتسمح بـ `rating` و`comment` بس.
  - السياسة بتسمح بتعديل التقييم وهو `active` فقط.
- **(و):**
  - **الإعدادات:** صفحة الإعدادات كانت بتعدّل مفاتيح مفيش أي كود بيقرأها. صلّحت الحفظ، وشلت حقلي السعر لأن الأسعار بقت في `payment_packages`.
  - **الحظر:** بقى حقيقياً عبر `ban_duration` في Auth. استدعاء `signOut(userId)` القديم كان بيبعت user id في مكان JWT، فماكانش بيشتغل أصلاً.

### نتائج كل الحزم بعد اكتمال 🟠
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | `db reset` بـ 14 migration، و`test db` 250/250 |
| Docker runner | 250/250 |
| Edge Functions | `deno test` 47/47. تكامل 3 ملفات كلها نجحت. `deno lint` فيه 8 مشاكل `any` في دوال لم تُلمس |
| Admin | Vitest 26/26 (منها 6 على Supabase محلي حقيقي)، tsc وlint وbuild كلها exit 0 |
| Flutter | 49/49، `analyze` فيه نفس الـ 15 مشكلة القديمة. التغطية **36.9%** (275 من 745 سطراً)، محسوبة على 9 ملفات من 60 حمّلتها الاختبارات. التغطية الحقيقية أقل |

---

## 13. ما تبقّى بعد 🟠

### بنود 🟠 من خطتي الأصلية (§6) لم تكن ضمن ترتيبك (أ)–(و)
| # | البند | السبب | الحجم |
|---|---|---|---|
| KYC-01 | `moderate_kyc` لا يضبط `is_id_verified` فشارة "موثّق" لا تظهر أبداً. مستندات الهوية لا تُحذف بعد القرار. الرقم القومي مخزّن نصاً واضحاً | FR-1.4 / NFR-2.2، وهو آخر 🐛 في المصفوفة | M |
| AI-01 | نماذج Claude المستخدمة متقاعدة، فكل مراجعة تسقط إلى "medium". `ai-content-review` و`analyze-ad-image` يقبلان مفتاح anon العام، فأي شخص يستهلك رصيد Anthropic. نص الإعلان يدخل الـ prompt مباشرة | تكلفة وأمان | M |
| OTP-01 | التطبيق يتجاوز حد الـ OTP بالرجوع لـ `signInWithOtp` مباشرة. لا يوجد حد لكل IP. رسالة الخطأ تكشف رقم وكود الاختبار | FR-1.1، إساءة استخدام SMS | S |
| QA-01 | `flutter analyze` (15 مشكلة) يُفشل الـ CI. لا يوجد CI للقاعدة واللوحة والدوال | جودة | M |

### 🟡 مرتبة حسب الأولوية (S ≤ نصف يوم، M = 1–2 يوم، L = 3–5 أيام، XL أكثر من أسبوع)
| # | البند | المتطلب | الحجم | ملاحظات |
|---|---|---|---|---|
| 1 | ~~واجهة حفظ البحث وإدارته (من شاشة البحث)~~ | FR-4.2 | M | ✔ §18 (`cbc6d6b`) |
| 2 | ~~مركز الإشعارات داخل التطبيق (قائمة، مقروء، شارة العدد)~~ | FR-4.2/6.1 | M | ✔ §18 (`f9bc95f`) |
| 3 | ~~اختيار المدينة في إعداد الملف الشخصي~~ | FR-1.3 | S | ✔ §18 (`e1bddc5`) |
| 4 | ~~فلتر الحي وتاريخ النشر~~ | FR-2.3 | S | ✔ §18 (`4690cca`) |
| 5 | انتهاء الإعلان من تاريخ الاعتماد بدل الإنشاء، وتمديده | FR-3.3 | S | |
| 6 | فرض حدود الباقات (عدد الإعلانات والصور) | FR-5.3 | M | في `create-ad` وفي الواجهة |
| 7 | Feed حسب الموقع (GPS) | FR-2.1 | M | العمود `location_point` موجود |
| 8 | إدارة أسعار الباقات من اللوحة (`payment_packages`) | FR-5.x | S–M | الأسعار حالياً تتغيّر بـ SQL فقط |
| 9 | ربط مفاتيح الإعدادات بسلوك فعلي أو إزالتها (`maintenance_mode`، `ai_moderation_enabled`، `enable_kyc_verification`، `enable_boost_feature`، `min_trust_score_to_post`) | FR-6 | M | حالياً لا يقرأها أي كود |
| 10 | حجب إعلانات المحظور، وإنهاء جلساته فوراً | FR-6.2 | S | |
| 11 | المرادفات في البحث | FR-2.2 | M | جدول مرادفات + توسيع الاستعلام |
| 12 | شاشة أداء الإعلان (فارغة الآن) | — | S–M | |
| 13 | عرض الخريطة مع Clusters | FR-2.4 | L | يحتاج مفتاح Google Maps |
| 14 | تسجيل الدخول بـ Facebook | FR-1.2 | S–M | إعداد Supabase + مراجعة تطبيق Meta |
| 15 | ضغط الصور وتحويلها لـ WebP على السيرفر | NFR-1.2 | M | |
| 16 | Offline cache للإعلانات المحفوظة | NFR-3.2 | M | |
| 17 | المراقبة (Sentry، Uptime، PostHog) | NFR-3.1 | M | |
| 18 | نقل 104 نصوص hardcoded لملفات الترجمة | NFR-4.1 | M | |
| 19 | محو المعاملات المجهولة بعد مدة الاحتفاظ | §6 | S | بعد تأكيد المدة قانونياً |
| 20 | التقاط سيلفي في التوثيق (بدون مطابقة آلية حسب قرارك) | FR-1.4 | S | |
| 21 | زر تسجيل الخروج في اللوحة (بدون handler) | — | S | |

### هندسة وجودة (مطلوبة لتعريف الاكتمال)
| البند | الحجم |
|---|---|
| تغطية اختبارات Flutter ≥ 70% + اختبار تكامل لرحلة نشر إعلان كاملة على emulator | L |
| طبقة Repositories بدل استعلامات Supabase داخل الـ providers (`ENGINEERING_STANDARDS.md` Rule 4.1) | L |
| `flutter build apk --release` / iOS، وتجربة الرحلات الخمس end-to-end على جهاز | M |
| التحقق الحقيقي: Paymob Sandbox، و FCM بـ service account، ومزوّد SMS | S لكل واحد، بعد توفّر المفاتيح |
| تحديث README (التشغيل المحلي، متغيرات البيئة، النشر) و FINAL_REPORT | S |

---

## 14. آخر أربعة بنود 🟠: AI-01، OTP-01، KYC-01، QA-01

| البند | الـ commit | الفشل قبل الإصلاح | بعد الإصلاح |
|---|---|---|---|
| AI-01 مراجعة الإعلانات بالذكاء الاصطناعي | `242ae3d` | النماذج متقاعدة فكل مراجعة كانت تسقط لـ "medium"، وأي حد بمفتاح anon يقدر يستهلك رصيد Anthropic | Deno 15 (moderation 9 + handler 6)، pgTAP 14 |
| OTP-01 حدود رموز التحقق | `a90ce09` | التطبيق كان بيتخطى الحد بنداء `signInWithOtp` مباشرة، ورسالة الخطأ بتكشف رقم وكود الاختبار | تكامل Auth محلي: الطلب الثاني خلال دقيقة اترفض بـ 429 ووقت الانتظار. Flutter 3 |
| KYC-01 الشارة والاحتفاظ بالمستندات | `8a2fb72` | الاعتماد مكانش بيضبط `is_id_verified` فالشارة مابتظهرش أبداً، والمستندات مابتتحذفش | pgTAP 18، وتكامل end-to-end: رفع حقيقي، اعتماد، شارة، حذف بعد 7 أيام، والمرفوض يفضل لحد 30 يوم |
| QA-01 الـ CI والتحليل | `e2898be` | `flutter analyze` فيه 14 مشكلة + 58 تحذير deprecation مخفيين بـ ignore، و`deno lint` فيه `any`، وتحذيرين في lint اللوحة، والـ CI بيشغّل Flutter بس | كل الأدوات صفر مشاكل بالإعدادات الصارمة، والـ CI بيشغّل كل الحزم |

- **AI-01:**
  - المراجعة على السيرفر بس، جوه `create-ad`. حُذفت `ai-content-review` و`analyze-ad-image` ومزوّد Flutter اللي كان بينادي عليهم.
  - 3 طبقات: regex، ثم نموذج سريع، ثم نموذج أعمق للحالات غير الواضحة. النماذج من متغيرات البيئة (`MODERATION_MODEL_FAST`/`DEEP`)، والافتراضي `claude-haiku-5-5` و`claude-sonnet-5-5`.
  - نص الإعلان بيدخل كبيانات جوه `<ad>` مش كتعليمات، والرد structured output بـ zod schema.
  - أي فشل (timeout، خطأ، رفض من النموذج، تجاوز 20 مراجعة يومياً للمستخدم) = `unreviewed`. الإعلان دايماً بيبدأ `pending` ويروح للمراجعة اليدوية، والـ AI مابيعتمدش إعلان لوحده.
  - كل قرار متسجّل في `ai_moderation_log` بالطبقة والنموذج والسبب. اللوحة بترتّب حسب الخطورة.
- **OTP-01:** الحدود اتنقلت لـ Supabase Auth نفسه. `config.toml` بيطبّقها محلياً بس، وقيم الإنتاج مكتوبة في production plan §4 ولازم تتضبط يدوياً في لوحة المشروع.
- **KYC-01:** `moderate_kyc` بيقرر في الطلبات المعلّقة بس. الحذف بيتم بـ cron يومي (`purge-kyc-documents`)، والقرار نفسه بيفضل محفوظ مع وقت الحذف. السياسة مكتوبة في privacy plan.
- **QA-01:**
  - **Flutter:** `flutter analyze --fatal-infos --fatal-warnings` = **No issues found**. شلت الـ ignores من `analysis_options.yaml` وصلّحت اللي كانت بتخفيه: `withOpacity` (49)، `value` في Dropdown (4)، `activeColor` (3)، `WillPopScope`، `anonKey`. مفاتيح JSON للشات بقت من `build.yaml` (`field_rename: snake`)، والـ `.g.dart` الناتج نفس المفاتيح بالظبط.
  - **Deno:** `deno lint` = 0 مشاكل على 35 ملف. مشكلة الـ `any` الوحيدة المتبقية كانت في `get-kyc-document`، واتحذفت بالكامل (انظر N13).
  - **اللوحة:** `next lint --max-warnings 0` = 0. خط Cairo بقى self-hosted بـ `next/font`. الـ `<img>` في معاينة KYC متساب عن قصد مع تعليق: الرابط مؤقت 5 دقائق لمستند هوية، و`next/image` كان هيعمله proxy وcache على السيرفر.
  - **CI** (`.github/workflows/ci.yml`، فحصه `actionlint` 1.7.7 بدون ملاحظات): gitleaks؛ pgTAP على `supabase start` من الصفر + تكامل Auth/Storage/KYC + تكامل اللوحة؛ deno check/lint/test؛ اللوحة typecheck/lint/build/vitest؛ Flutter analyze صارم + test. شغّلت خطوات التكامل محلياً بنفس الأوامر ونجحت. **الـ workflow نفسه لسه ماشتغلش على GitHub** لأن الفرع ماتعملوش push.

### نتائج جديدة
| # | النتيجة | الحالة |
|---|---|---|
| N13 | `get-kyc-document` كانت بتدّي رابط موقّع لمستند هوية لأي توكن مشرف بدون فحص `aal2`، يعني بتتخطى إلزام الـ MFA للـ staff. ومحدش بيستخدمها | اتحذفت (`e2898be`) ومن `deploy_functions.bat` وproduction plan |
| N14 | الرقم القومي كان مخزّن نصاً واضحاً في `user_verifications.national_id` | مُصلح (§15) |
| N15 | لو النموذج رفض يصنّف إعلان، ماستخدمتش fallback لنموذج تاني. الرفض بيتعامل كـ `unreviewed` ويروح للمراجعة اليدوية | قرار تصميم، مش ثغرة |
| N16 | `next build` في اللوحة محتاج `NEXT_PUBLIC_SUPABASE_URL/ANON_KEY` وقت البناء، لأن صفحة `/login` بتتعمل prerender. ده كان موجود قبل التعديل | الـ CI بيمرّر قيم placeholder. النشر لازم يمرّر القيم الحقيقية وقت البناء |

### ما لم يُتحقق منه
- نداء حقيقي لـ Anthropic (مفيش مفتاح على الجهاز). الكود مختبر بـ classifier وهمي ومطابق لتوثيق الـ SDK.
- مزوّد SMS حقيقي، FCM حقيقي، Paymob Sandbox، وأي تجربة على جهاز.
- تشغيل الـ CI على GitHub.

### نتائج كل الحزم بعد §14
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | 16 migration، `test db` **283/283** |
| Edge Functions | `deno check` و`deno lint` 0 مشاكل، `deno test` **65/65**. تكامل محلي (Auth OTP، Storage، KYC) 4 اختبارات / 18 خطوة كلها نجحت |
| Admin | tsc 0، `next lint --max-warnings 0` 0، build نجح، Vitest **26/26** (منها 6 تكامل على Supabase محلي) |
| Flutter | `analyze --fatal-infos --fatal-warnings` **0**، `flutter test` **52/52** |

**كل بنود 🟠 خلصت.** قائمة 🟡 في §13 زي ما هي، ومابدأتش فيها.

---

## 15. N14: الرقم القومي مايتخزنش

**القرار:** آخر 4 أرقام + `HMAC-SHA256(الرقم بعد التطبيع, KYC_NATIONAL_ID_HMAC_SECRET)`.

| | |
|---|---|
| Migration | `20261029090000_kyc_national_id_hmac.sql`: حذف `national_id`، إضافة `national_id_last4` و`national_id_hmac` مع قيود الصيغة، unique index جزئي، وصلاحيات SELECT على مستوى العمود |
| الكود | `submit-kyc-request/national_id.ts` (تطبيع + HMAC + رفض التشغيل من غير secret طوله 32 على الأقل)، و`handler.ts`، و`deps.ts`، و`index.ts` |
| اللوحة | صفحة KYC بتعرض `••••••••••1234` جنب صور البطاقة |
| التطبيق | بيطبّع الأرقام العربية قبل التحقق والإرسال (كان بيرفضها)، وبيقرا أعمدة محددة بدل `*` |
| الفشل قبل الإصلاح | pgTAP 16: 14/14 فشلوا |

**الأدلة:**
- **pgTAP 16 (14 اختبار):**
  - مفيش عمود `national_id`. الأعمدة الوحيدة اللي فيها "national" في `public` هي last4 وhmac.
  - last4 مايقبلش 14 رقم، والـ hmac مايقبلش غير 64 hex، والاتنين لازم يتخزنوا مع بعض.
  - التكرار على حساب تاني بيترفض وهو pending أو approved. بعد الرفض، نفس المستخدم يقدر يقدّم تاني، وده بيرجع يحجز الرقم.
  - المستخدم مايقدرش يقرأ الـ HMAC ولا `code_hash` حتى على طلبه.
- **Deno (7 اختبارات):**
  - المسافات والأرقام العربية بنوعيها والـ NBSP بتطلّع نفس الـ HMAC.
  - الـ HMAC بيتغير لو المفتاح اتغير، ومش هو نفس SHA-256 العادي.
  - مفيش تشغيل من غير secret.
  - الصف المخزّن مافيهوش الرقم الكامل.
  - التكرار بيترفض بالرسالة العامة قبل رفع أي صورة. ولو حصل تكرار في نفس اللحظة والـ index مسكه، الصور اللي اترفعت بتتمسح.
- **تكامل محلي (Postgres + Storage حقيقيين):**
  - الصف المخزّن مافيهوش الرقم.
  - حساب تالت قدّم نفس الرقم بأرقام عربية ومسافات، واترفض بالرسالة العامة. مافيش صف ولا صور متبقية.

**ملاحظات:**
- الـ unique index **جزئي** (`pending` و`approved` بس). لو كان على كل الصفوف، المستخدم المرفوض مايقدرش يقدّم تاني بنفس رقمه. وكمان طلب اترفض لأنه ببطاقة حد تاني كان هيحجز الرقم على صاحبه الحقيقي للأبد.
- الرسالة العامة واحدة سواء الرقم مستخدم في حساب تاني أو المستخدم نفسه عنده طلب معتمد بنفس الرقم.
- تغيير الـ secret بيبطّل كشف التكرار للطلبات القديمة. ده موثّق في privacy plan §4 وproduction plan §3 و`.env.example`.

### نتيجة جديدة
| # | النتيجة | الحالة |
|---|---|---|
| N17 | سبب رفض الـ KYC بيتسجّل في `audit_logs` بس. `user_verifications` مافيهوش عمود `rejection_reason`، فالتطبيق دايماً بيعرض رسالة الرفض الافتراضية (`verification_screen.dart:64`) | مُصلح (§18) |

---

## 16. الـ push، الـ CI على GitHub، وقائمة الربط

- **الـ push:** الفرع `fix/audit` اترفع على `origin`، ومفيش merge على `main`. الـ workflow كان بيشتغل بس على push لـ `main`/`develop`، فوسّعت الـ trigger لكل الفروع.
- **gitleaks قبل الـ push** (v8.21.2 على كل التاريخ): لقى 10 نتائج، وفحصتها كلها، ومفيش ولا واحدة سر حقيقي:
  - 6 منها JWT، فكّيتها وكلها `role: anon` لمشروعي الـ dev (مفاتيح عامة بطبيعتها، ومطابقة لفحص §3.5).
  - مفتاح RSA بيتولّد وقت تشغيل الاختبار، وده بس الـ header بتاعه.
  - قيمتين وهميتين في اختبارات.
  - placeholder مقطوع في الـ README.
  - اتسجلت في `.gitleaksignore` بالـ fingerprint، كل واحدة مع سببها، وبعدها الفحص بقى "no leaks found". أي نتيجة جديدة لسه هتفشّل الـ CI.
- **نتيجة الـ CI على GitHub:** [run 40383329027](https://github.com/Maamoun0/wasla/actions/runs/40383329027). الخمس jobs ماشتغلوش أصلاً: "The job was not started because your account is locked due to a billing issue". **محتاج تصلّح الـ billing في حساب GitHub.** مفيش فرق بين المحلي وGitHub أقدر أشوفه قبل كده.
- GitHub نبّه إن `ubuntu-latest` بيتنقل لـ Ubuntu 26. ثبّتّ `ubuntu-24.04` عشان النتيجة تبقى قابلة للتكرار.
- **قائمة الربط:** `docs/INTEGRATION_CHECKLIST.md` فيها كل سر، وفين يتحط، والأمر اللي بيثبت إنه شغال. وفيه 4 اختبارات حية جديدة في `supabase/tests/live/` (Anthropic وFCM وPaymob sandbox وSMS)، بتتخطى نفسها من غير الأسرار، واتأكدت إنها بتعمل type-check. **ولا واحد فيهم اشتغل على خدمة حقيقية لحد دلوقتي.**

---

## 17. رسائل SMS عن طريق Send SMS Hook

**القرار:** Auth مش مربوط بأي مزوّد SMS مدمج. Auth بينده Edge Function اسمها `send-sms-hook`، والطلب متوقّع بـ Standard Webhooks.

| | |
|---|---|
| الكود | `send-sms-hook/handler.ts` (التحقق من التوقيع، وصياغة الرسالة، والفشل المغلق)، و`deps.ts` (`standardwebhooks@1.0.0`، وبيقبل كذا secret مفصولين بـ `\|` وقت التغيير)، و`providers/types.ts` (واجهة `SmsProvider`، والقناة `sms`/`whatsapp`)، و`providers/twilio.ts`، و`providers/registry.ts` (`SMS_PROVIDER`، `SMS_CHANNEL`) |
| مزوّد جديد | ملف في `providers/` + سطر في `registry.ts` |
| WhatsApp | القناة معرّفة، بس مفيش مزوّد بيدعمها، فاختيارها بيوقف الإعداد بخطأ صريح |
| الرسالة | "رمز التحقق في وصلة: 123456 / لا تشاركه مع أي شخص." 43 حرف، يعني مقطع SMS واحد |
| السجلات | فيها اسم المزوّد، وآخر 3 أرقام من الموبايل، وكود خطأ المزوّد بس. لا الرمز ولا نص الرسالة ولا رسالة خطأ المزوّد (لأنها ممكن تكرر بيانات الطلب) |
| الإعداد المحلي | `[auth.hook.send_sms]` و`[edge_runtime.secrets]` في `config.toml`، والقيم في `supabase/.env` (المثال في `supabase/.env.example`). الـ edge runtime بقى شغال محلياً وفي الـ CI |

**الأدلة:**
- **Deno (10 اختبارات):**
  - المزوّد الوهمي بيستقبل `+201012345678` والرمز بالظبط.
  - الطلب من غير توقيع، أو بمفتاح غلط، أو بعد ما اتعدّل، بيترفض بـ 401 قبل ما يوصل للمزوّد.
  - فشل المزوّد أو استثناء غير متوقع بيرجع خطأ لـ Auth، من غير الرمز في السجل.
  - مفيش مزوّد = فشل مغلق.
  - Twilio بيبعت الحقول اللي في التوثيق، ومش بيسجّل رسالة الخطأ.
- **تكامل حقيقي** (`supabase/tests/auth/send_sms_hook.local.ts`): GoTrue ← الـ hook في الـ edge runtime ← Twilio وهمي على الجهاز:
  - الرمز اللي وصل للمزوّد بيدخّل المستخدم فعلاً.
  - **حد الـ 60 ثانية من OTP-01 لسه شغال**: الطلب التاني بيرجع 429، والـ hook مابيتندهش.
  - فشل المزوّد بيرجع للتطبيق 500 ومعاه "SMS provider failed to send the code"، والرقم مابيتقفلش، فالمستخدم يقدر يعيد على طول.
  - النداء من غير توقيع = 401.
  - **مفيش أي OTP في سجلات حاويتي Auth والـ edge runtime.**

**ملاحظتين اتعلمتهم من التشغيل الحقيقي:**
1. Auth بيقرأ `{error:{http_code,message}}` بس لو الـ HTTP status كان 200. أي status تاني بيتحول لرسالة عامة ("Unexpected status code returned from hook"). عشان كده أخطاء المزوّد والإعداد بترجع 200 ومعاها جسم الخطأ، وAuth بيحوّلها لخطأ حقيقي للتطبيق. ورفض التوقيع بيفضل 401.
2. الـ CLI مابيشغّلش تسجيل الدخول بالموبايل غير لو فيه مزوّد مدمج متعرّف، فبلوك Twilio بالقيم الوهمية رجع، ومعاه تعليق. مع تفعيل الـ hook، Auth مابيستخدمهوش، والاختبار بيثبت ده.

### نتيجة جديدة
| # | النتيجة | الحالة |
|---|---|---|
| N18 | GoTrue المحلي شغال بـ `GOTRUE_SMS_OTP_EXP=6000`، مع إن `config.toml` فيه `otp_expiry = 300` | مفتوح. يتراجع في لوحة الإنتاج (production plan §4 فيه 300) |

---

## 18. أول 5 بنود 🟡: N17 ثم 1–4 من §13

| البند | الـ commit | الفشل قبل الإصلاح | بعد الإصلاح |
|---|---|---|---|
| N17 سبب رفض الـ KYC | `0a558e1` | pgTAP 17: 6/6 فشلوا (العمود مش موجود) | السبب بيتخزن (متقصوص لـ 500 حرف بدل ما القرار يفشل)، وصاحبه بس اللي بيقراه، والتطبيق بيعرضه |
| 🟡1 حفظ البحث | `cbc6d6b` | pgTAP 18: المطابقة القديمة (`ILIKE` على الجملة كلها) ماطابقتش "سيارة" مع "سياره"، ولا "كورولا تويوتا" مع "تويوتا كورولا" | زرار "احفظ البحث" في شاشة البحث. المطابقة بقت زي البحث (تطبيع عربي + بادئة كل كلمة) + نوع الإعلان. التحقق: لازم شرط واحد على الأقل، ومفاتيح معروفة بس، وحد 20. والمستخدم مايقدرش يكتب `last_notified_at` |
| 🟡2 مركز الإشعارات | `f9bc95f` | pgTAP 19: 9/9 فشلوا. وكمان جدول `notifications` **ماكانش في publication الـ realtime**، فالـ stream والشارة ماكانوش بيتحدثوا خالص | قائمة (آخر 50)، وغير المقروء متميز، ووقت نسبي بالعربي، والضغط بيعلّم مقروء ويفتح الإعلان أو إعلاناتي (نفس توجيه الـ push)، و"تحديد الكل كمقروء"، والشارة من عدّ السيرفر |
| 🟡3 المدينة في إعداد الملف | `e1bddc5` | الشاشة ماكانش فيها مدينة. صلاحية السيرفر كانت سليمة، وpgTAP 20 بيثبّتها | محافظة ثم مدينة، إجباري عند الحفظ (والتخطي لسه متاح). widget test للتسلسل والإجبار |
| 🟡4 فلتر الحي والتاريخ | `4690cca` | pgTAP 21: 10/10 فشلوا (`search_ads` مالهاش المعاملات) | `p_district_id` و`p_posted_within_days` (من 1 لـ 365 يوم حسب وقت النشر). الشيت فيه محافظة ← مدينة ← حي + تاريخ النشر، وبيفتح على الفلاتر المطبّقة. البحث المحفوظ بيشيل الحي وتنبيهه بيطابقه |

**إصلاحات جانبية اتعملت لأنها كانت بتكسر البنود دي:**
- شيت الفلاتر كان بيمسح نص البحث، والبحث كان بيمسح الفلاتر. دلوقتي كل واحد بيغيّر الجزء بتاعه بس.
- تبويب البحث المحفوظ كان `FutureBuilder` مابيتحدثش، فالبحث المحذوف كان بيفضل ظاهر. اتنقل لـ provider، والحذف بقى بتأكيد، والضغط على البحث بيفتحه.
- الوقت النسبي بقى بصيغ العدد العربية الصح (دقيقة، دقيقتين، 5 دقائق، 25 دقيقة).

### نتائج جديدة
| # | النتيجة | الحالة |
|---|---|---|
| N19 | الضغط على قسم في الرئيسية بيروح لـ `/explore?category=ID`، بس مسار Explore بيتجاهل `category`، فـ**فلتر القسم مابيتطبّقش في أي مكان في التطبيق**، مع إن `search_ads` بيدعمه (القسم الرئيسي بيشمل الفرعي) | مفتوح، S. محتاج ترتيبك |

### نتائج كل الحزم بعد §18
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | 21 migration، `test db` **340/340** |
| Edge Functions | `deno check` و`deno lint` 0 مشاكل (44 ملف)، `deno test` **82/82** |
| تكامل محلي | Auth OTP، والـ SMS Hook (Auth حقيقي ← edge runtime ← Twilio وهمي)، وStorage، وKYC: **5 اختبارات / 23 خطوة** |
| Admin | tsc 0، lint 0، Vitest **26/26** |
| Flutter | `analyze --fatal-infos --fatal-warnings` **0**، `flutter test` **70/70** |
| CI على GitHub | **لسه مقفول بسبب الـ billing** (آخر run: `ef6e397`، ولا job بدأ) |

**وقفت بعد أول 5 بنود زي ما طلبت.** البند التالي في §13 هو رقم 5 (انتهاء الإعلان من تاريخ الاعتماد).
