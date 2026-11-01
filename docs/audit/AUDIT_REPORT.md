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
| FR-1.2 | تسجيل اجتماعي Google + Facebook | — | Supabase Auth (Google وFacebook) | `auth_screen.dart`، `auth_provider.dart` | — | widget | ⚠️ | §22: زرار Facebook اتضاف. متبقٍ: تطبيق Meta، وتجربة الاتنين على جهاز |
| FR-1.3 | إعداد الملف (مدينة، اسم، صورة) | `users.city_id`، bucket `avatars` | — | `profile_setup_screen.dart` (محافظة ← مدينة) | — | pgTAP 14 + 20 + Storage 9 + widget 2 | ⚠️ | §18: اختيار المدينة اتنفّذ. متبقٍ: التجربة على جهاز |
| FR-1.4 | KYC: وجه/ظهر + سيلفي + مطابقة + شارة | `user_verifications` | `submit-kyc-request` (سيلفي إلزامي)، `purge-kyc-documents`، `moderate_kyc` | `verification_screen.dart` (5 خطوات) | `kyc/` | pgTAP 15–17 + Deno + تكامل KYC | ⚠️ | §22: السيلفي اتضاف، والمراجع بيقارنه بنفسه (من غير مطابقة آلية، حسب قرارك). متبقٍ: التجربة على جهاز |
| FR-2.1 | Feed حسب موقع GPS | `search_ads(p_near_lat, p_near_lng, p_radius_km)` + PostGIS | — | `home_screen.dart` (الأحدث / الأقرب لي)، `location_service.dart` | — | pgTAP 24 + widget 3 | ⚠️ | §20: الأقرب أولاً في نطاق 50 كم، والإعلان من غير إحداثيات بياخد مركز مدينته، والموقع بيتقرّب لـ 1 كم ومابيتخزنش. متبقٍ: التجربة على جهاز |
| FR-2.2 | بحث نصي عربي بالمرادفات والأخطاء | `normalize_arabic`، `search_ads()`، trigram، `search_synonyms` | — | `ads_provider.dart` | — | pgTAP 11 + 30 + Flutter | ⚠️ | §21: المرادفات (سيارة/عربية، موبايل/جوال، لابتوب/لاب توب…) في البحث والتنبيهات. متبقٍ: توسيع قائمة المرادفات من بيانات الاستخدام الحقيقية |
| FR-2.3 | فلاتر: قسم، سعر، مدينة، حي، نوع، تاريخ | `search_ads(p_district_id, p_posted_within_days)` | — | `explore_screen.dart` (شيت الفلاتر) | — | pgTAP 21 + widget 2 + Flutter | ⚠️ | §18: الحي والتاريخ والمدينة في الشيت، والفلاتر مابقتش تمسح البحث. §19: فلتر القسم بيوصل من الرئيسية والـ URL (N19). متبقٍ: التجربة على جهاز |
| FR-2.4 | عرض خريطة مع Clusters | `ads_map_clusters` (تجميع على السيرفر حسب التقريب) | — | `ads_map.dart` (خريطة في البحث) | — | pgTAP 32 + Flutter 4 | ⚠️ | §21: الخريطة والتجميع اتنفّذوا، والمفتاح بيتحقن وقت البناء. **ماتجرّبش العرض**: محتاج مفتاح Google Maps وجهاز |
| FR-3.1 | معالج 5 خطوات، حتى 8 صور | `ad_media` | `create-ad` | `post_ad/` (6 شاشات) | — | `post_ad_wizard_test.dart` | ⚠️ | حد 8 صور في العميل فقط (`add_photos_screen.dart:24`)؛ لا تحقق في الخادم؛ لا integration test |
| FR-3.2 | حقول ديناميكية حسب القسم | `category_fields`, `get_category_fields()` | `create-ad` (يتحقق من الإلزامي والقيم) | `category_fields_provider.dart` | — | pgTAP 14 + Deno 5 | ⚠️ | مُصلح (§10): كل الأقسام الفرعية لها حقول. متبقٍ: تجربة المعالج على جهاز فعلي |
| FR-3.3 | معلَّق → مراجعة → نشط 30 يوماً | `ad_lifetime()`، `set_ad_published_at`، `renew_ad`، cron `expire-ads` | `moderate_ad` | `my_ads_screen.dart` (ينتهي خلال… / تجديد) | `ads/` | pgTAP 05 + 22 + Flutter | ⚠️ | §20: المدة بتبدأ من الاعتماد (`ad_expiry_days`)، والمالك مايقدرش يغيّر التواريخ، والتجديد في آخر 3 أيام أو بعد الانتهاء. متبقٍ: التجربة على جهاز |
| FR-4.1 | مفضلة + ملاحظات | `favorites.notes` | — | `saved_screen.dart:79-163` | — | ❌ | ⚠️ | العرض موجود؛ لم أجد تحريراً للملاحظة؛ غير مختبر |
| FR-4.2 | بحث محفوظ + إشعار فوري | `saved_searches` (تحقق + حد 20)، `notifications`، `notifications_outbox` | `dispatch-notifications` (FCM v1) | `explore_screen.dart` (احفظ البحث)، `saved_screen.dart`، `notifications_screen.dart` | — | pgTAP 18 + 19 + 21 + Flutter + Deno | ⚠️ | §18: الحفظ من شاشة البحث، والمطابقة بقت زي البحث (تطبيع عربي)، ومركز إشعارات بشارة حية. متبقٍ: FCM حقيقي (مستني service account) |
| FR-4.3 | تسجيل نقرات الاتصال/واتساب | `contact_logs` | — | `ads_provider.dart:253` | — | ❌ | ⚠️ | سياسة الإدراج `WITH CHECK (TRUE)` (`wasla-schema.sql:896`) → تزوير/إغراق الإحصائيات |
| FR-4.4 | تقييم 1-5 + رد واحد للمعلن | `reviews`, `review_responses` | — | `reviews_controller.dart` | — | pgTAP 13 | ⚠️ | مُصلح (§11): الإدراج يعمل وصيغة الثقة موحّدة. متبقٍ: N12 (المقيِّم يقدر يعدّل حالة تقييمه) |
| FR-5.1 | Paymob (بطاقة، فوري، محفظة) | `transactions`, `payment_packages`, `fulfill_payment()` | `create-payment`, `payment-webhook` | `payment_webview_screen.dart` | — | pgTAP 26 + Deno 23 | ⚠️ | 🔴(ب) مُصلح ومختبر محلياً (§9). متبقٍ: تجربة Paymob Sandbox فعلية، وتكامل فوري/المحفظة (يوجد integration بطاقة واحد فقط) |
| FR-5.2 | Featured / Urgent / Bump | `ad_boosts`, `payment_packages`, cron | `fulfill_payment()` | `boost_ad_screen.dart`, `boost_controller.dart` | — | pgTAP 26 | ⚠️ | النوع والمدة من الباقة على السيرفر (§9). متبقٍ: Sandbox + انتهاء الصلاحية عبر cron غير مختبر |
| FR-5.3 | اشتراكات تجارية بحدود أعلى | `subscription_plans`، `user_plan`، `posting_block` | `create-ad` (فحص قبل الـ AI) | `plan_usage_provider.dart`، خطوة الصور، اختيار القسم | — | pgTAP 23 + 25 + Deno + Flutter | ⚠️ | §20: حدود الإعلانات والصور حسب الباقة بتتطبّق على السيرفر. متبقٍ: **قرار حد صور الباقة المجانية** (4 في الجدول مقابل 8 في الـ SRS)، وتجربة الدفع الحقيقي للاشتراك |
| FR-6.1 | مراجعة الإعلانات + سبب + إشعار | `ad_moderation_log` | `moderate_ad` + outbox | — | `ads/` | pgTAP + Vitest | ⚠️ | الاعتماد/الرفض والإشعار يعملان (§10). متبقٍ: تجربة اللوحة يدوياً من المتصفح |
| FR-6.2 | بلاغات + حظر | `reports`، `audit_logs`، `apply_user_block`، `account_blocked` | `handle_report`، الدوال بتتحقق من الحظر | بلاغ من `ad_detail_screen.dart` | `reports/`، `users/` | Vitest + تكامل + pgTAP 29 + Deno | ⚠️ | §21: الحظر بيخفي الإعلانات وبينهي الجلسات فوراً، والتوكن المتبقي ممنوع من النشر والتواصل والدفع والتوثيق. متبقٍ: مسار البلاغات يدوياً في اللوحة |
| NFR-1.1 | الصفحة الرئيسية ≤ 2 ثانية | فهارس | — | pagination موجود | — | `scripts/wasla-load-test.js` لم يُشغَّل | ❌ | لا قياس |
| NFR-1.2 | ضغط تلقائي وتحويل WebP على السيرفر | Storage image transformation | `/storage/v1/render/image` | `ImageUtils` | — | تكامل محلي + Flutter | ⚠️ | §22: الصور بتتصغر وبتتبعت WebP من السيرفر (اتجرّب على Storage حقيقي). متبقٍ: الخطة المدفوعة (Pro) على المشروع المستضاف |
| NFR-2.1 | HTTPS/TLS | — | Supabase/Paymob https | — | — | ❌ | ⚠️ | الافتراضي https؛ لم يُتحقق من إعدادات الإنتاج |
| NFR-2.2 | مستندات الهوية خاصة + روابط مؤقتة للمشرف | bucket خاص `id-documents` | `purge-kyc-documents` (cron يومي) | — | `getKycDocumentUrl` (staff + aal2) | Vitest + pgTAP 18 + تكامل KYC | ⚠️ | 🔴(ج) و§14: الروابط تصدر من اللوحة فقط بعد aal2، وحُذفت `get-kyc-document` لأنها كانت تتجاوز الـ MFA، والمستندات تُحذف بعد القرار، والرقم القومي مايتخزنش (N14). متبقٍ: تجربة اللوحة يدوياً من المتصفح |
| NFR-3.1 | توافرية 99.9% | — | دالة `health` | — | — | Deno 4 + نداء حقيقي | ⚠️ | §22: endpoint للـ uptime. متبقٍ: قرار Sentry/PostHog، وربط خدمة uptime |
| NFR-3.2 | Offline cache للإعلانات المحفوظة | — | — | `saved_ads_provider.dart` | — | Flutter 4 | ⚠️ | §22: المحفوظات بتتعرض من غير إنترنت، وبتتمسح عند تسجيل الخروج |
| NFR-4.1 | عربية كاملة RTL + خط Cairo | — | — | خطوط Cairo + `easy_localization` (`ar-EG.json`) | `dir="rtl"` | ❌ | ⚠️ | 104 نص عربي hardcoded في `Text('…')` مقابل 113 استخدام `.tr()` |
| NFR-4.2 | Android 8+ / iOS 13+ | — | — | iOS target 13.0؛ Android `flutter.minSdkVersion` | — | ❌ | ⚠️ | لا اختبار على أجهزة |

**الإجمالي (محدَّث بعد §22):** ✅ 0 — ⚠️ 27 — ❌ 1 — 🐛 0

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
| 5 | ~~انتهاء الإعلان من تاريخ الاعتماد بدل الإنشاء، وتمديده~~ | FR-3.3 | S | ✔ §20 (`868d800`) |
| 6 | ~~فرض حدود الباقات (عدد الإعلانات والصور)~~ | FR-5.3 | M | ✔ §20 (`af3155e`) |
| 7 | ~~Feed حسب الموقع (GPS)~~ | FR-2.1 | M | ✔ §20 (`e908bc4`) |
| 8 | ~~إدارة أسعار الباقات من اللوحة (`payment_packages`)~~ | FR-5.x | S–M | ✔ §20 (`7fdf2d6`) |
| 9 | ~~ربط مفاتيح الإعدادات بسلوك فعلي أو إزالتها (`maintenance_mode`، `ai_moderation_enabled`، `enable_kyc_verification`، `enable_boost_feature`، `min_trust_score_to_post`)~~ | FR-6 | M | ✔ §20 (`9f9ccec`) |
| 10 | ~~حجب إعلانات المحظور، وإنهاء جلساته فوراً~~ | FR-6.2 | S | ✔ §21 (`62a18de`) |
| 11 | ~~المرادفات في البحث~~ | FR-2.2 | M | ✔ §21 (`142cde7`) |
| 12 | ~~شاشة أداء الإعلان (فارغة الآن)~~ | — | S–M | ✔ §21 (`d027878`) |
| 13 | ~~عرض الخريطة مع Clusters~~ | FR-2.4 | L | ✔ §21 (`6ba13a0`) |
| 14 | ~~تسجيل الدخول بـ Facebook~~ | FR-1.2 | S–M | ✔ §22 (`141631e`) |
| 15 | ~~ضغط الصور وتحويلها لـ WebP على السيرفر~~ | NFR-1.2 | M | ✔ §22 (`21c51e9`) |
| 16 | ~~Offline cache للإعلانات المحفوظة~~ | NFR-3.2 | M | ✔ §22 (`3193854`) |
| 17 | ~~المراقبة (Sentry، Uptime، PostHog)~~ | NFR-3.1 | M | ✔ §22 (`32ad5ed` health) + §23 (`d027205` Sentry). PostHog اتأجل |
| 18 | نقل 104 نصوص hardcoded لملفات الترجمة | NFR-4.1 | M | ⏸ اتأجل لبعد الإطلاق (§23). الحجم الحقيقي 529 نص |
| 19 | محو المعاملات المجهولة بعد مدة الاحتفاظ | §6 | S | بعد تأكيد المدة قانونياً |
| 20 | ~~التقاط سيلفي في التوثيق (بدون مطابقة آلية حسب قرارك)~~ | FR-1.4 | S | ✔ §22 (`5843cc1`) |
| 21 | ~~زر تسجيل الخروج في اللوحة (بدون handler)~~ | — | S | ✔ §23 (`5d96e7e`) |

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
| N19 | الضغط على قسم في الرئيسية بيروح لـ `/explore?category=ID`، بس مسار Explore بيتجاهل `category`، فـ**فلتر القسم مابيتطبّقش في أي مكان في التطبيق**، مع إن `search_ads` بيدعمه (القسم الرئيسي بيشمل الفرعي) | **🟠**، مُصلح (§19، `e6c6f17`) |

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

---

## 19. N19 (اترفع لـ 🟠) ومراجعة المسارات في التطبيق كله

### N19: فلتر القسم (`e6c6f17`)
- **المشكلة:** الرئيسية بتفتح `/explore?category=ID`، والمسار بيتجاهل الـ query، فالقسم مابيتطبّقش في أي مكان. ونفس الكلام في `?featured=true`.
- **الإصلاح:**
  - `/explore` بيقرأ `q`، و`category`، و`city`، و`district`، و`type`، و`min`، و`max`، و`days`، و`featured` عند الفتح، ولما الـ URL يتغير.
  - `/explore` من غير parameters بيسيب البحث المفتوح زي ما هو.
  - أي تغيير في الفلتر بيعمل `replace` للـ URL، فالتاريخ مابيكبرش.
  - الرئيسية بتعمل `push`، فزرار الرجوع بيرجع للرئيسية.
- **مشكلة اكتشفتها وأنا بصلّح:** الرئيسية والبحث كانوا بيشتركوا في نفس الـ provider، فالقسم اللي بتختاره في البحث كان بيغيّر قائمة الرئيسية. الرئيسية بقى ليها `homeAdsNotifierProvider` لوحدها.
- **الاختبارات (widget):**
  - الضغط على "مركبات" في الرئيسية بيفتح البحث، و`p_category_id = 1` بيوصل لـ `search_ads`، وبيظهر القسم وأقسامه الفرعية بس.
  - الرجوع بيرجع للرئيسية.
  - deep link فيه `category` و`q` بيفتح البحث ده، والتعديل بيحدّث الـ URL.
  - أما إن القسم الرئيسي بيشمل الفرعي على السيرفر، فده متغطي في pgTAP 11.

### جدول المسارات
كل `go`/`push`/`replace`، وكل توجيه إشعار، وكل deep link. "بتتقري؟" معناها: الشاشة اللي بتستقبل بتقرأ الـ parameter فعلاً.

| المصدر | الوجهة | الـ parameters | بتتقري؟ | الحالة |
|---|---|---|---|---|
| `home_screen.dart:225` (قسم) | `/explore` | `?category=` | ✅ بعد الإصلاح | ✔ N19 |
| `home_screen.dart:273` (المميز) | `/explore` | `?featured=true` | ✅ بعد الإصلاح | ✔ N19 |
| `home_screen.dart:91,141`، `saved_screen.dart:103,244`، bottom nav | `/explore` | — | — | ✅ |
| `saved_screen.dart:260` (بحث محفوظ) | `/explore` | الفلتر في الـ provider ثم `go` | ✅ (الـ URL بيتزامن) | ✅ |
| `home_screen.dart:63` | `/notifications` | — | — | ✅ |
| `AdCard` (`wasla_logo.dart:154`)، `saved_screen.dart:139`، `my_ads_screen.dart:229`، `seller_profile_screen.dart:264`، `ad_success_screen.dart:95` | `/ad/:id` | path `id` | ✅ | ✅. كان **محجوب على الزوار** بالـ guard، واتصلّح |
| `ad_detail_screen.dart:263` | `/seller/:id` | path `id` | ✅ | ✅. كان محجوب على الزوار، واتصلّح |
| صور الإعلان (`ad_detail_screen.dart`) | `/photos/:adId` | path + `?index=` | ✅ | **المسار كان موجود ومحدش بيفتحه**. اتربط |
| `ad_detail_screen.dart:51,64`، `profile_screen.dart:51`، `saved_screen.dart:400` | `/auth` | — | — | ✅. بس بعد الدخول المستخدم بيروح للرئيسية مش للصفحة اللي كان فيها (N22) |
| `auth_screen.dart:59,67` | `/auth/otp` | `?phone=&wait=` | ✅ (`app_router`) | ✅ |
| `otp_screen.dart:88,90`، `splash_screen.dart`، `onboarding_screen.dart` | `/auth/setup`، `/home`، `/onboarding`، `/auth` | — | — | ✅ |
| `select_category_screen.dart:97` ← `ad_form:304` ← `add_photos:255` ← `location_price:440` | `/post/form` ← `/post/photos` ← `/post/location` ← `/post/preview` | الحالة في `postAdWizardProvider` | ✅ | ✅ |
| `ad_preview_screen.dart:36` | `/post/success` | `?id=` | ✅ (`GoRouterState` في `ad_success_screen.dart:16`) | ✅. الرسالة كانت بتقول إن الـ AI هيفعّل الإعلان، واتصلّحت |
| `my_ads_screen.dart:224` | `/profile/boost/:id` | path `id` | ✅ | ✅ |
| `my_ads_screen.dart:226` | `/profile/performance/:id` | path `id` | ✅ | ✅ (الشاشة نفسها فاضية، وده 🟡 #12) |
| `boost_ad_screen.dart:347`، `subscription_screen.dart:401` | `/profile/payment` | `extra` (Map) | ✅ | **كانت بتقع لو مفيش `extra`** (cast إجباري)، واتصلّح |
| `profile_screen.dart` (القائمة) | `/profile/my-ads`، `/saved`، `/profile/subscription`، `/profile/verify`، `/profile/reviews`، `/settings` | — | — | ✅ |
| `profile_screen.dart` "التنبيهات المحفوظة" | `/saved` | — | ❌ كانت بتفتح المفضلة | اتصلّح: `?tab=alerts` |
| `settings_screen.dart:233` | `/settings/notifications` | — | — | ✅ |
| `conversations_screen.dart:61` | `/chat/:id` | path `id` | ❌ **المسار مش موجود** | N20 |
| (لا شيء) | `ConversationsScreen`، `ChatDetailScreen` | — | — | N20: مش مربوطين بأي مسار |
| `AppRoutes.admin` (`/admin`) | — | — | — | ثابت ملوش استخدام ولا مسار، مش بيعمل ضرر |
| Push (`main.dart`) + القائمة داخل التطبيق | `/ad/:id` (`watchlist_match`)، `/profile/my-ads` (`ad_status_change`) | `data.ad_id` | ✅ (`notificationRoute`) | ✅ (§18) |
| Deep link `wasla://login-callback` (Google) | Supabase / app_links | `code` | Android ✅. **iOS ❌ مفيش URL scheme** | اتصلّح (`CFBundleURLTypes`). ماتجرّبش على جهاز |

### أزرار فاضية
| المكان | المشكلة | الحالة |
|---|---|---|
| `settings_screen.dart:279` سياسة الخصوصية | `onTap: () {}` | N21 |
| `settings_screen.dart:286` شروط الاستخدام | `onTap: () {}` | N21 |

مفيش أي TODO، أو "قريباً"، أو `UnimplementedError` في `lib/`.

### الإصلاحات الصغيرة (`0539415`)، كل واحد بـ widget/unit test في `test/core/routes_test.dart`
1. **الـ guard:** `isPublicLocation` بيسمح بتصفح الإعلانات والبائعين والصور. والمحفوظ والملف الشخصي والإشعارات بيعرضوا رسالة الدخول بتاعتهم. الباقي محتاج جلسة.
2. **عارض الصور:** اتربط.
3. **التنبيهات المحفوظة:** بتفتح تبويبها.
4. **صفحة الدفع:** من غير بيانات بتعرض "ابدأ من جديد" بدل ما تقع.
5. **`Info.plist`:** كان **XML غير صالح** (`< RowanUIInterfaceOrientationLandscapeRight` من commit `333e1e7`، قبل التدقيق)، وده بيكسر أي build لـ iOS. وكمان ماكانش فيه URL scheme. اتصلّح الاتنين، والـ CI بقى بيتأكد إن `Info.plist` و`AndroidManifest.xml` سليمين. الفحص بيفشل على الملف القديم، اتأكدت من ده.
6. **رسالة نجاح النشر:** اتصلّحت.

### بنود جديدة كبيرة
| # | البند | الحالة |
|---|---|---|
| N20 | الشات: جداول `conversations`/`messages` وشاشتين وprovider موجودين، بس مفيش مسار ولا زرار يوصّل ليهم. والشات مش من متطلبات الـ SRS الـ 28، والـ RLS بتاعه ماتراجعش | مُصلح جزئياً: اتأجل لـ 1.1 واتقفل (§21) |
| N21 | سياسة الخصوصية وشروط الاستخدام: الزرارين فاضيين، ومفيش نص قانوني في الريبو. المتاجر بتطلب رابط سياسة خصوصية | مسودات + موافقة بإصدار (§21). النص النهائي محتاج مراجعة قانونية |
| N22 | الدخول من صفحة محمية بيرجّع المستخدم للرئيسية مش للصفحة اللي كان فيها | مُصلح (§21) |

---

## 20. 🟡 من 5 لـ 9

| البند | الـ commit | الفشل قبل الإصلاح | بعد الإصلاح |
|---|---|---|---|
| 🟡5 انتهاء الإعلان والتجديد (FR-3.3) | `868d800` | pgTAP 22: الإعلان اللي استنى 10 أيام في المراجعة اخد 20 يوم بس. اللي استنى أكتر من 30 يوم انتهى في نفس الساعة بعد الاعتماد. **والمالك كان يقدر يكتب `expires_at` بنفسه**، يعني إعلان مابينتهيش | المدة (`ad_expiry_days`) بتبدأ من الاعتماد. التواريخ بيحددها النظام بس. `renew_ad` للإعلان المنتهي أو اللي في آخر 3 أيام، ومن غير ما يتحسب "منشور جديد" ومن غير إشعار تاني. و"ينتهي خلال…" + زرار "تجديد" في إعلاناتي |
| 🟡6 حدود الباقات (FR-5.3) | `af3155e` | pgTAP 23: الحدود ماكانتش متطبّقة خالص. **و`ad_media` كان مفتوح للكتابة من العميل**، فكان ممكن تبدّل صور إعلان بعد اعتماده من غير مراجعة (N23) | الباقة = اشتراك نشط وإلا المجانية. الإعلانات الحية = معلّق + نشط. الحد بيتفحص قبل مراجعة الـ AI (عشان مايتصرفش رصيد) وتاني جوه المعاملة. الصور بقت كتابتها من السيرفر بس. والتطبيق بيعرض حد الصور من الباقة وبينبّه عند حد الإعلانات |
| (جانبي) رسائل أخطاء الدوال | `093f809` | `functions.invoke` بيرمي `FunctionException` مع أي رد غير 2xx، فكود `status != 200` ماكانش بيشتغل أصلاً. رسائل `create-ad` و`create-payment` و`submit-kyc-request` كانت بتوصل نص استثناء خام أو "خطأ اتصال" | helper موحّد بيقرأ رسالة الدالة وكودها. اختبار Flutter |
| 🟡7 الأقرب لي (FR-2.1) | `e908bc4` | pgTAP 24: `search_ads` ماكانش فيه موقع. الدالة القديمة `get_ads_near_me` كانت بتتجاهل الإعلانات اللي من غير إحداثيات والمحذوفة، ومحدش بيستخدمها. **و Android ماكانش فيه أي إذن موقع** | الأقرب أولاً في نطاق 50 كم، والمميز في النطاق قبل الباقي. الإعلان من غير إحداثيات بياخد مركز مدينته. الإذن (تقريبي) بيتطلب عند الضغط بس، والموقع بيتقرّب لـ 1 كم ومابيتخزنش ولا بيدخل في الروابط |
| 🟡8 أسعار الباقات من اللوحة | `7fdf2d6` | الأسعار كانت بتتغير بـ SQL بس | `/dashboard/packages` للأدمن بس: السعر والاسم والترتيب والتفعيل. المدة والنوع ثابتين لأن `fulfill_payment` بيقرأ المدة وقت الدفع. تغيير السعر مايأثرش على عملية دفع شغالة، لأنها بتتحاسب بالمبلغ المخزّن في المعاملة. تأكيد قبل تغيير السعر، وسجل تدقيق. Vitest 17 + اختبار تكامل على قاعدة البيانات الحقيقية |
| 🟡9 مفاتيح الإعدادات | `9f9ccec` | pgTAP 25: ولا مفتاح من الخمسة كان مقروء في أي كود. **واللوحة كانت بتعرض 20 كحد أدنى لمؤشر الثقة لو الصف مش موجود**، ولو اتطبّق كان هيمنع أي مستخدم جديد (بيبدأ من 0) من النشر | كل مفتاح بقى بيعمل اللي مكتوب عليه، والإنفاذ على السيرفر (الجدول تحت). الصفوف الناقصة اتضافت بالسلوك الحالي، والقيمة الافتراضية للحد الأدنى في اللوحة بقت 0 |

**المفاتيح الخمسة:**
| المفتاح | السيرفر | التطبيق |
|---|---|---|
| `maintenance_mode` | قاعدة البيانات بترفض الإعلانات الجديدة والتجديد. `create-payment` و`submit-kyc-request` بيرجّعوا 503 | شريط في الرئيسية |
| `min_trust_score_to_post` | `posting_block` بيرفض النشر تحت الحد | رسالة الرفض من السيرفر |
| `ai_moderation_enabled` | `create-ad` مابينادش النموذج، والإعلان بيروح للمراجعة البشرية | — |
| `enable_boost_feature` | `create-payment` بيرفض الترويج | زرار الترويج بيختفي |
| `enable_kyc_verification` | `submit-kyc-request` بيرفض | بند التوثيق بيختفي من الملف الشخصي |

### نتائج جديدة
| # | النتيجة | الحالة |
|---|---|---|
| N23 | `ad_media` كان مفتوح للإضافة والحذف من صاحب الإعلان في أي وقت، فكان ممكن تبدّل الصور بعد الاعتماد من غير مراجعة ومن غير حد | مُصلح (`af3155e`) |
| N24 | `functions.invoke` بيرمي استثناء مع أي رد غير 2xx، فرسائل الرفض من الدوال ماكانتش بتوصل للمستخدم صح | مُصلح (`093f809`) |
| N25 | جدول `cities` في الـ seed فيه **29 مدينة مكررة من أصل 58** (نفس المحافظة ونفس الاسم، زي سموحة 25 و54)، فكل قوائم المدن بتعرضها مرتين | الدمج والـ unique اتعملوا (§21). الـ seed الرسمي مستني مصدر |

### قرارات محتاجها منك
1. **حد صور الباقة المجانية:** الجدول بيقول 4، والـ SRS (FR-3.1) بيقول "حتى 8 صور". الإنفاذ دلوقتي ماشي على الجدول. لو القرار 8، ده تعديل بيانات في migration سطر واحد.
2. **N20 الشات:** نكمّله ولا نشيله؟
3. **N21:** نص سياسة الخصوصية وشروط الاستخدام، أو رابط ليهم.
4. **N25:** موافقة على دمج المدن المكررة.

### نتائج كل الحزم بعد §20
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | 26 migration، `test db` **389/389** |
| Edge Functions | `deno check` و`deno lint` 0 مشاكل، `deno test` **89/89** |
| تكامل محلي | **5 اختبارات / 23 خطوة** (Auth OTP، SMS Hook، Storage، KYC) |
| Admin | tsc 0، lint 0، build نجح، Vitest **44/44** (منها 7 تكامل) |
| Flutter | `analyze --fatal-infos --fatal-warnings` **0**، `flutter test` **95/95** |
| CI على GitHub | راجع الحالة في رسالة النتائج |

**المصفوفة:** مابقاش فيه أي 🐛. FR-5.3 بقى ⚠️ بعد ما اتطبّقت الحدود، وFR-2.1 بقى ⚠️ بعد ما كان ❌.

---

## 21. القرارات الأربعة، وN22، و🟡 من 10 لـ 13

### القرارات
| البند | الـ commit | التنفيذ |
|---|---|---|
| حد صور الباقة المجانية | `a251d4b` | الباقة المجانية بقت **8** (زي الـ SRS)، والبريميوم 12، والأعمال 20. وpgTAP 23 بيتأكد من القيم دي |
| N20 الشات | `dcb0699` | اتأجل لـ 1.1. الجدولين اتقفلوا على كل أدوار العميل (pgTAP 26). الشاشات والـ providers اتشالت، والـ migrations زي ما هي. زرار "اتصال" (`tel:`) وزرار "واتساب" (`wa.me` برسالة جاهزة فيها عنوان الإعلان) بيعدّوا الاتنين على `reveal_seller_phone`، اللي بيسجّل في `contact_logs`. ومفيش حاجة تانية بقت بتستخدم `freezed`/`json_serializable`، بس سبتهم في `pubspec` لأن شيلهم تغيير مكتبات |
| N21 الخصوصية والشروط | `5f0cd2f` | `docs/legal/DATA_INVENTORY.md` معمول من الكود، ومعاه مسودتين مكتوب عليهم "مسودة — تحتاج مراجعة قانونية". الشاشتين بيعرضوا النص من `app_configs` برقم إصدار، والإصدار 0 مكتوب فيه "قيد المراجعة". الموافقة بتتسجّل على الإصدار نفسه |
| N25 المدن | `47dc345` | الدمج والحذف اتعملوا، ومعاهم unique على (المحافظة، الاسم بعد التطبيع) للمدن، و(المدينة، الاسم) للأحياء |

**اتلقى أثناء N21 واتصلّح:**
- خانة الموافقة في التسجيل كانت **متعلّمة افتراضياً** "لتسهيل الاختبار".
- `legal_acceptances` كان ممكن أي حد يكتب فيه، حتى `anon`، وبأي إصدار.
- شاشة الـ OTP كانت بتسجّل إصدار `v1.0` مالوش وجود، وبتبلع أي خطأ.
- روابط الشروط كانت لدومين `wasla.app` محدش متأكد إنه موجود.

### N25: الـ seed الرسمي للمراكز والمدن
- **بعد الدمج:** فاضل **29 مدينة، كلها في 3 محافظات** (القاهرة 15، والإسكندرية 7، والجيزة 7). **الـ 24 محافظة التانية مالهاش ولا مدينة**، يعني المستخدم هناك مايقدرش يختار مدينته ولا ينشر إعلان. **ده يمنع الإطلاق.**
- **ليه مافيش seed كامل:** دوّرت على مصدر رسمي. موقع الجهاز المركزي للتعبئة العامة والإحصاء (capmas.gov.eg) تطبيق JavaScript، والصفحة الرئيسية فيه بتعرض إحصائيات سكان لكل محافظة بس، من غير قائمة المراكز والأقسام. وموقع وزارة التنمية المحلية (mld.gov.eg) ماردّش على الاتصال. **ماكتبتش البيانات من الذاكرة**، زي ما طلبت.
- **المطلوب:** ملف رسمي من CAPMAS (التقسيم الإداري، أو نتائج تعداد 2017 على مستوى المركز والقسم)، أو رابط لمصدر حكومي ينفع يتقرا. وأنا أحوّله لـ migration، ورابط المصدر فيه.

### N22 (`b845e38`)
- الـ guard بيودّي الزائر لـ `/auth?from=<الصفحة>`، وبعد الدخول بيرجع للصفحة دي، مروراً بالـ OTP وإعداد الملف.
- **مشكلة اتلقت:** الدخول بجوجل كان بيسيب المستخدم واقف على شاشة الدخول. دلوقتي بيرجع لـ `from` أو للرئيسية.
- `safeReturnPath` بيقبل مسارات جوه التطبيق بس، فمايبقاش فيه open redirect ولا loop.

### 🟡 من 10 لـ 13
| البند | الـ commit | الفشل قبل الإصلاح | بعد الإصلاح |
|---|---|---|---|
| 🟡10 الحظر | `62a18de` | pgTAP 29: إعلانات المحظور كانت بتفضل ظاهرة، وجلساته بتفضل شغالة | trigger بيخفي الإعلانات ويمسح الجلسات والـ refresh tokens. والتوكن المتبقي (ساعة بالكتير) ممنوع من النشر وعرض الأرقام والدفع والتوثيق |
| 🟡11 المرادفات | `142cde7` | pgTAP 30: "سيارة" ماكانتش بتلاقي "عربية" | مجموعات مرادفات كبيانات، بتشتغل في البحث والتنبيهات، والعبارات مدعومة |
| 🟡12 أداء الإعلان | `d027878` | pgTAP 31: **`views_count` ماكانش بيزيد خالص**، والشاشة كانت فاضية | `record_ad_view` (صاحب الإعلان مايتحسبش، والمسجّل مرة في اليوم، والزوار بحد أقصى في الدقيقة، ومن غير IP، والسجل التفصيلي بيتمسح بعد 90 يوم)، و`ad_performance` لصاحب الإعلان بس، والشاشة فيها رسم بياني لـ 30 يوم |
| 🟡13 الخريطة | `6ba13a0` | pgTAP 32. **ومفتاح Google Maps كان placeholder مكتوب في الكود**، فحتى شاشة تحديد المكان في نشر الإعلان ماكانتش هتشتغل | التجميع على السيرفر حسب التقريب، بنفس فلاتر البحث. الخريطة في البحث: المجموعة بتقرّب، والإعلان الواحد بيفتح صفحته. المفتاح بيتحقن وقت البناء من `MAPS_API_KEY` أو ملف مش في git. بنيت APK debug بالمتغير، واتأكدت إن المفتاح وصل للـ manifest المدمج (الـ build كشف غلطتين في سكربت Kotlin واتصلّحوا). **العرض نفسه ماتجرّبش** (محتاج مفتاح وجهاز). القسم 6 في `INTEGRATION_CHECKLIST.md` |

### نتائج كل الحزم بعد §21
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | 34 migration، `test db` **457/457** |
| Edge Functions | `deno check` و`deno lint` 0 مشاكل، `deno test` **91/91** |
| تكامل محلي | **5 اختبارات / 23 خطوة** |
| Admin | tsc 0، lint 0، Vitest **44/44** |
| Flutter | `analyze --fatal-infos --fatal-warnings` **0**، `flutter test` **117/117** |
| CI على GitHub | راجع رسالة النتائج |

---

## 22. التقسيم الإداري الرسمي (للمراجعة)، و🟡 14–17 و20

### المدن من المصدر الرسمي (`0c02323`): مستنية مراجعتك
- **المصدر:** COD-AB من CAPMAS على HDX، بترخيص CC BY-IGO، إصدار v01، صالح من 2017-04-21. اتنزّل في `data/sources/` مع الـ sha256. **الأسماء العربية موجودة**، بس في `adm*_name1` (و`lang1 = ar`) مش في أعمدة `_AR`.
- **المستوى 1:** 27 محافظة، كلها مطابقة للموجود بفروق إملائية بس.
- **المستوى 2:** 365 صف، اتصنّفوا لـ 174 مدينة (مراكز ومدن جديدة)، و173 حي (أقسام)، و18 استبعاد مقترح. فيه 142 صف متعلّم للمراجعة.
- **مفيش migration:** مستني ردك على `docs/data/ADMIN_MAPPING.md`.
- **غلطات في البيانات الحالية اتكشفت بالمقارنة:** "شبرا الخيمة" و"حدائق الأهرام" متسجلين في القاهرة، وهما في القليوبية والجيزة.

### 🟡
| البند | الـ commit | الملاحظة |
|---|---|---|
| 14 Facebook | `141631e` | زرار وprovider. محتاج تطبيق Meta (قائمة الربط §7) |
| 15 WebP | `21c51e9` | **`thumbnail` كان بيحط width/quality على رابط بيتجاهلهم**، فكل القوائم كانت بتنزّل الصور بحجمها الكامل. دلوقتي بتعدّي على `render/image`. اختبار التكامل: الصورة رجعت WebP بأقل من نص الحجم. وعلى المشروع المستضاف محتاجة خطة Pro |
| 16 Offline | `3193854` | آخر نسخة من المحفوظات بتتخزن على الجهاز وبتتعرض من غير إنترنت، وبتتمسح عند تسجيل الخروج. وقبل كده أي خطأ كان بيظهر كـ "مفيش محفوظات" |
| 17 المراقبة | `32ad5ed` (جزئي) | دالة `health` (اتجرّبت على الـ edge runtime المحلي: 200). Sentry وPostHog مستنيين قرار. والاختبار كشف إن timer بيتسرّب مع كل طلب، واتصلّح |
| 20 السيلفي | `5843cc1` | خطوة سيلفي بالكاميرا الأمامية، وإلزامي في الدالة. في التكامل المحلي اترفع 3 ملفات، والحذف المجدول مسحهم الـ 3 |

### اتأجلوا لقرار
- **🟡18 الترجمة:** الحجم الحقيقي **529 نص عربي في 45 ملف**، مش 104. ومحتاج قرارين: الفصحى ولا العامية، وإن اختبارات الـ widget (حوالي 40) تحمّل ملفات الترجمة.
- **🟡19 محو المعاملات:** مستني تأكيد مدة الاحتفاظ قانونياً.

### نتائج كل الحزم بعد §22
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | 34 migration، `test db` **457/457** |
| Edge Functions | `deno check` و`deno lint` 0 مشاكل (47 ملف)، `deno test` **96/96** |
| تكامل محلي | **6 اختبارات / 23 خطوة** (ضاف اختبار ضغط الصور) |
| Admin | tsc 0، lint 0، Vitest **44/44** |
| Flutter | `analyze --fatal-infos --fatal-warnings` **0**، `flutter test` **125/125** |

## 23. Sentry، و🟡21، والهندسة والجودة (4 بنود)، ومسودة الأحياء

### القرارات اللي اتسجلت
- **🟡18 الترجمة:** اتأجلت لبعد الإطلاق (قرارك يوم 2026-11-01). الحجم المقاس 529 نص في 45 ملف.
- **🟡15 Pro:** اتوافق عليها، ومتسجلة في `docs/wasla_production_migration_plan.md` §3.1.
- **PostHog:** اتأجل. Sentry بس.

### التقسيم الإداري (مفيش migration لحد ما تقول «مؤكد»)
| الـ commit | اللي اتعمل |
|---|---|
| `947ca32` | المحافظات الحضرية: كل قسم منطقة، والأقسام المرقّمة بتتدمج، والاسم المعروض من غير قسم/مركز، والاسم الرسمي في عمود منفصل. 275 منطقة في 27 محافظة |
| `64490fd` | مسودة الأحياء من ردّك، وجدول أسماء بحث بديلة (فيصل ← العمرانية وبولاق الدكرور، ووسط البلد ← قصر النيل وعابدين والأزبكية)، وقائمة المراجعة. تصليح مسافة «مصرالجديدة» (EG0128) |
| `36bdf3e` | 19 مدينة من موقع هيئة المجتمعات العمرانية، كل واحدة برابط صفحتها. المحافظة مكتوبة في صفحة المنصورة الجديدة بس، والباقي اقتراح متعلّم 🔎. و6 أسماء مش على الموقع «تحت التحقق» |

**محتاج قرارك:** «قسم الهرم» و«قسم الطالبية» مش في مصدر 2017. فيه «قسم الأهرام» (EG2106)، ومش هعتبره نفس القسم من غير تأكيدك.

### البنود
| البند | الـ commit | الدليل |
|---|---|---|
| 🟡17 Sentry | `d027205` | التطبيق والـ admin والـ 9 دوال. مقفول من غير DSN، و`sendDefaultPii = false`، و`beforeSend` بيشيل الأرقام والبريد والـ tokens وبيسيب معرّف المستخدم بس وبيشيل الـ headers والـ cookies ومحتوى الطلبات. اختبار في Deno بعت حدث حقيقي لخادم محلي واتأكد إن اللي وصل مفيهوش رقم ولا بريد. `sentry_flutter` 8 و9.0 كانوا بيفرضوا Kotlin 1.6 فالبناء بيفشل، و9.30.1 اشتغلت (APK اتبنى). اتضاف لـ DATA_INVENTORY ومسودة الخصوصية، مع فجوة: منطقة التخزين ومدة الاحتفاظ لسه مااتحددوش |
| 🟡21 خروج اللوحة | `5d96e7e` | الزرار بقى server action بيعمل signOut ويرجّع لصفحة الدخول. اختبار Vitest |
| README | `847a04f` | اتكتب من الكود: طريقة التشغيل والمتغيرات والاختبارات. التعليمات القديمة (ملف `.env` للتطبيق) كانت غلط، لأن التطبيق بياخدها بـ `--dart-define` |
| بناء release | `f39cf1d` | التوقيع من `key.properties` (برّه git) أو `WASLA_KEY_PROPERTIES`. اتبنى APK release بمفتاح تجريبي اتمسح بعدها: 70.6 ميجا، و`apksigner` أكّد التوقيع بالمفتاح ده مش بمفتاح debug. **iOS ماتبناش** (محتاج Mac) |
| طبقة Repositories | `7254ac4` | 10 repositories في `lib/data/repositories`، وكل استعلام اتنقل زي ما هو. اختبار بيفشل لو ظهر وصول مباشر لـ Supabase برّه الـ repositories، واتجرّب بملف مزروع وفشل فعلاً. والاستثناءات: بدء التطبيق وخدمة الإشعارات الـ static |
| تغطية Flutter | `d4f9265` + الـ commit الجاي | **من 27.8% لـ 71.7%** من كل ملفات `lib` (لو حسبنا الملفات اللي اتحمّلت بس: 76.9%). 51 اختبار شاشة جديد (من 137 لـ 188) على backend وهمي في الذاكرة بيسجّل الطلبات |

**أخطاء حقيقية لقيتها الاختبارات (`d4f9265`):**
- `default_avatar.png` و`placeholder.png` كانوا ملفات فاضية (0 بايت)، فأي مستخدم من غير صورة كان بيظهر بصورة مكسورة.
- شاشة OTP كانت بتعمل dispose للـ controller مرتين.
- dialog حذف الحساب كان بيعمل dispose للـ controller وهو لسه بيتقفل.

**كود ميت:** `wasla_haptics.dart` و`wasla_image.dart` و`trust_score_widget.dart` محدش بيستخدمهم. سبتهم، ومحسوبين في التغطية كأنهم مش متغطيين.

### اختبار رحلة النشر على المحاكي
`integration_test/post_ad_journey_test.dart` (`4fd0dcb`) اشتغل على المحاكي (Android 14) قدّام الـ stack المحلي. سجّل دخول برقم الاختبار المحلي، ومشي في التطبيق الحقيقي من اختيار القسم لحد النشر. الكاميرا والمعرض بس اللي وهميين.

- **أول تشغيل:** الإعلان اتنشر، بس الاختبار وقف على خطأ شكل حقيقي: كل زرار في الشريط السفلي كان بيطلع برّه مساحته بـ pixel واحد على الموبايل. اتصلّح في `7d5deb8`.
- **بعد التصليح:** نجح من غير أي استثناء.
- **في قاعدة البيانات:** إعلانين بحالة `pending`، كل واحد عليه صورتين، و4 ملفات في `ads`.
- **الإعداد اللي احتاجه:** `create-ad` بيقبل روابط الصور من `PUBLIC_SUPABASE_URL` بس، والمحاكي بيوصل للـ stack على `10.0.2.2`. فاتعمل `supabase/functions/.env` محلي (برّه git) فيه السطر ده، واتعمل restart للـ stack.

### اتأجل أو مستني
- **🟡19:** مستني مدة الاحتفاظ القانونية.
- **التحقق الحقيقي** (Paymob وFCM ومزوّد SMS وSentry نفسه): محتاج مفاتيح.
- **الـ CI:** حساب GitHub لسه مقفول بسبب الفوترة.

### نتائج كل الحزم بعد §23
| الحزمة | النتيجة |
|---|---|
| Supabase CLI | 34 migration، `test db` **457/457** |
| Edge Functions | `deno check` و`deno lint` 0 مشاكل، `deno test` **101/101** |
| تكامل محلي | **6 اختبارات / 23 خطوة** |
| Admin | tsc 0، lint 0، `next build` نجح، Vitest **50/50** |
| Flutter | `analyze --fatal-infos --fatal-warnings` **0**، `flutter test` **188/188**، والتغطية **71.7%** |
| المحاكي | رحلة النشر **1/1** |
| Android | APK debug بـ Sentry، وAPK release موقّع بمفتاح الرفع (التوقيع اتأكد بـ apksigner) |

## 24. قرارات الأحياء، والتنضيف، وقائمة ما قبل الإطلاق

| البند | الـ commit | الدليل |
|---|---|---|
| الهرم وفيصل | `95d8c37` | الهرم بقى قسم الأهرام EG2106، والاسم المعروض «الهرم»، و«الأهرام» اسم بحث بديل. فيصل بقى حي تحت العمرانية مؤقتاً، والبحث بيلاقيه في بولاق الدكرور كمان |
| بيانات المحاكي | `0e2d8bc` | الإعلانين التجريبيين وملفاتهم الأربعة اتمسحوا من الـ stack المحلي عن طريق Storage API. والاختبار بقى يمسح إعلانه وصوره بعد ما يخلص، نجح أو فشل. اشتغل تاني على المحاكي ونجح، وفضل 0 إعلان و0 ملف |
| الملفات الميتة | `266c9bc` | `wasla_haptics` و`wasla_image` مكانوش مستخدمين، فاتمسحوا. `TrustScoreWidget` كان نسخة تانية من `TrustBadge` بحدود مختلفة (80/50 بدل 70/40)، و`TrustBadge` ظاهر فعلاً في صفحة البائع وصفحة الإعلان والمعاينة. الـ SRS مابيطلبش تقييم تاني، فاتمسح بدل ما يظهر رقمين متعارضين. التغطية بقت **73.0%** من `lib` |
| قائمة ما قبل الإطلاق | الـ commit ده | `docs/LAUNCH_CHECKLIST.md`، مقسّمة حسب المسؤول (صاحب المشروع، والمستشار القانوني، ومزوّد الخدمة، والمطوّر)، وقدّام كل بند الأمر أو الاختبار اللي يثبت إنه خلص |

**يتنقل لما يظهر مصدر أحدث:** فيصل ← «قسم الطالبية» (LAUNCH_CHECKLIST D6).
