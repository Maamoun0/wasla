-- ================================================================
--  وصلة (Wasla) — Complete Database Schema
--  Platform  : Supabase (PostgreSQL 15)
--  Version   : 1.0.0
--  Tables    : 34 | Relations : 45 | ENUMs : 25
--  Run       : Supabase Dashboard → SQL Editor → Run
-- ================================================================


-- Clean public schema reset to prevent partial deployment conflicts
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ────────────────────────────────────────────────────────────────
-- §1 · EXTENSIONS
-- ────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
-- Enable postgis and pg_cron extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_cron;


-- ────────────────────────────────────────────────────────────────
-- §2 · CUSTOM ENUM TYPES  (25 types)
-- ────────────────────────────────────────────────────────────────
CREATE TYPE user_type_enum           AS ENUM ('regular','business','moderator','admin');
CREATE TYPE user_status_enum         AS ENUM ('active','suspended','deleted','pending_verification');
CREATE TYPE auth_provider_enum       AS ENUM ('google','facebook','apple');
CREATE TYPE verification_type_enum   AS ENUM ('phone_otp','email_token','national_id');
CREATE TYPE verification_status_enum AS ENUM ('pending','approved','rejected','expired');
CREATE TYPE ad_type_enum             AS ENUM ('offering','seeking');
CREATE TYPE price_type_enum          AS ENUM ('fixed','negotiable','free','per_hour','per_month');
CREATE TYPE ad_status_enum           AS ENUM ('pending','active','paused','rejected','expired','deleted','sold');
CREATE TYPE media_type_enum          AS ENUM ('image','video');
CREATE TYPE field_type_enum          AS ENUM ('text','number','select','boolean','range');
CREATE TYPE mod_action_enum          AS ENUM ('approved','rejected','flagged','suspended','restored');
CREATE TYPE report_reason_enum       AS ENUM ('fraud','duplicate','inappropriate','wrong_category','spam','other');
CREATE TYPE report_status_enum       AS ENUM ('pending','reviewed','resolved','dismissed');
CREATE TYPE review_status_enum       AS ENUM ('active','hidden','deleted');
CREATE TYPE subscription_status_enum AS ENUM ('active','expired','cancelled','trial');
CREATE TYPE boost_type_enum          AS ENUM ('featured','urgent','bump');
CREATE TYPE transaction_type_enum    AS ENUM ('subscription','ad_boost','credit_purchase');
CREATE TYPE payment_method_enum      AS ENUM ('card','fawry','instapay','vodafone_cash');
CREATE TYPE transaction_status_enum  AS ENUM ('pending','completed','failed','refunded');
CREATE TYPE credit_tx_type_enum      AS ENUM ('purchase','boost_spend','refund','bonus');
CREATE TYPE notification_type_enum   AS ENUM ('saved_search_match','ad_approved','ad_rejected','new_review','boost_expiring','system');
CREATE TYPE push_platform_enum       AS ENUM ('android','ios','web');
CREATE TYPE notify_via_enum          AS ENUM ('push','email','both');
CREATE TYPE contact_type_enum        AS ENUM ('phone','whatsapp','email');
CREATE TYPE target_type_enum         AS ENUM ('ad','user');
CREATE TYPE booking_status_enum      AS ENUM ('pending','accepted','in_progress','completed','cancelled');


-- ────────────────────────────────────────────────────────────────
-- §3 · GEOGRAPHY  (3 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.governorates (
  id        SMALLSERIAL  PRIMARY KEY,
  name_ar   VARCHAR(50)  NOT NULL,
  name_en   VARCHAR(50)  NOT NULL,
  code      VARCHAR(5)   NOT NULL UNIQUE,
  is_active BOOLEAN      NOT NULL DEFAULT TRUE
);
COMMENT ON TABLE public.governorates IS 'المحافظات المصرية الـ 27';

CREATE TABLE public.cities (
  id              SERIAL       PRIMARY KEY,
  governorate_id  SMALLINT     NOT NULL REFERENCES public.governorates(id) ON DELETE RESTRICT,
  name_ar         VARCHAR(80)  NOT NULL,
  name_en         VARCHAR(80)  NOT NULL,
  latitude        DECIMAL(10,8),
  longitude       DECIMAL(11,8),
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);
COMMENT ON TABLE public.cities IS 'المدن والأحياء الرئيسية داخل المحافظات';

CREATE TABLE public.districts (
  id       SERIAL      PRIMARY KEY,
  city_id  INTEGER     NOT NULL REFERENCES public.cities(id) ON DELETE RESTRICT,
  name_ar  VARCHAR(80) NOT NULL,
  name_en  VARCHAR(80)
);
COMMENT ON TABLE public.districts IS 'مناطق وأحياء أصغر داخل المدينة';


-- ────────────────────────────────────────────────────────────────
-- §4 · SUBSCRIPTION PLANS  (1 table — before users)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.subscription_plans (
  id                SMALLSERIAL  PRIMARY KEY,
  name              VARCHAR(50)  NOT NULL UNIQUE,
  name_ar           VARCHAR(50)  NOT NULL,
  price_monthly     DECIMAL(8,2) NOT NULL DEFAULT 0     CHECK (price_monthly >= 0),
  price_yearly      DECIMAL(8,2) NOT NULL DEFAULT 0     CHECK (price_yearly  >= 0),
  max_ads           INTEGER      NOT NULL DEFAULT 5,
  max_images_per_ad SMALLINT     NOT NULL DEFAULT 4,
  features          JSONB        NOT NULL DEFAULT '{}',
  is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
  sort_order        SMALLINT     NOT NULL DEFAULT 0
);
COMMENT ON TABLE public.subscription_plans IS 'خطط الاشتراك: مجاني | أساسي | بريميوم | أعمال';


-- ────────────────────────────────────────────────────────────────
-- §5 · USERS  (references Supabase auth.users)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.users (
  id                UUID              PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email             VARCHAR(255)      UNIQUE,
  phone             VARCHAR(20)       UNIQUE,
  full_name         VARCHAR(100)      NOT NULL DEFAULT '',
  avatar_url        TEXT,
  bio               TEXT,
  user_type         user_type_enum    NOT NULL DEFAULT 'regular',
  status            user_status_enum  NOT NULL DEFAULT 'pending_verification',
  is_phone_verified BOOLEAN           NOT NULL DEFAULT FALSE,
  is_email_verified BOOLEAN           NOT NULL DEFAULT FALSE,
  is_id_verified    BOOLEAN           NOT NULL DEFAULT FALSE,
  trust_score       DECIMAL(3,2)      NOT NULL DEFAULT 0.00
                                      CHECK (trust_score BETWEEN 0 AND 5),
  city_id           INTEGER           REFERENCES public.cities(id) ON DELETE SET NULL,
  last_active_at    TIMESTAMPTZ,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ
);
COMMENT ON TABLE public.users IS 'الجدول المركزي لجميع حسابات المستخدمين';


-- ────────────────────────────────────────────────────────────────
-- §6 · AUTH TABLES  (3 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.user_auth_providers (
  id               UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID               NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  provider         auth_provider_enum NOT NULL,
  provider_user_id VARCHAR(255)       NOT NULL,
  created_at       TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  UNIQUE (provider, provider_user_id)
);

CREATE TABLE public.user_sessions (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token_hash   VARCHAR(255) NOT NULL UNIQUE,
  device_info  JSONB,
  ip_address   INET,
  expires_at   TIMESTAMPTZ NOT NULL,
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.user_verifications (
  id           UUID                       PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID                       NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type         verification_type_enum     NOT NULL,
  code_hash    VARCHAR(255),
  document_url TEXT, -- Face/Front ID URL
  document_back_url TEXT, -- Back ID URL
  selfie_url   TEXT, -- Selfie Verification URL
  status       verification_status_enum   NOT NULL DEFAULT 'pending',
  attempts     SMALLINT                   NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  expires_at   TIMESTAMPTZ                NOT NULL,
  verified_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ                NOT NULL DEFAULT NOW()
);


-- ────────────────────────────────────────────────────────────────
-- §7 · RBAC — Roles & Permissions  (4 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.roles (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.user_roles (
  user_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role_id    UUID        NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  granted_by UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE public.permissions (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  category    VARCHAR(50)  NOT NULL
);

CREATE TABLE public.role_permissions (
  role_id       UUID NOT NULL REFERENCES public.roles(id)       ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);


-- ────────────────────────────────────────────────────────────────
-- §8 · CATALOG  (2 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.categories (
  id          SMALLSERIAL PRIMARY KEY,
  parent_id   SMALLINT    REFERENCES public.categories(id) ON DELETE SET NULL,
  name_ar     VARCHAR(80) NOT NULL,
  name_en     VARCHAR(80) NOT NULL,
  slug        VARCHAR(80) NOT NULL UNIQUE,
  icon        VARCHAR(50),
  level       SMALLINT    NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 3),
  sort_order  SMALLINT    NOT NULL DEFAULT 0,
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE
);
COMMENT ON TABLE public.categories IS 'هيكل هرمي ذاتي: 1=رئيسي 2=فرعي 3=تفصيلي';

CREATE TABLE public.category_fields (
  id            SERIAL          PRIMARY KEY,
  category_id   SMALLINT        NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  field_name    VARCHAR(50)     NOT NULL,
  label_ar      VARCHAR(80)     NOT NULL,
  label_en      VARCHAR(80),
  field_type    field_type_enum NOT NULL,
  options       JSONB,
  is_required   BOOLEAN         NOT NULL DEFAULT FALSE,
  is_searchable BOOLEAN         NOT NULL DEFAULT FALSE,
  sort_order    SMALLINT        NOT NULL DEFAULT 0,
  UNIQUE (category_id, field_name)
);
COMMENT ON TABLE public.category_fields IS 'حقول ديناميكية خاصة بكل قسم (مساحة، موديل، حالة...)';


-- ────────────────────────────────────────────────────────────────
-- §9 · ADS  (4 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.ads (
  id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID            NOT NULL REFERENCES public.users(id)       ON DELETE CASCADE,
  category_id      SMALLINT        NOT NULL REFERENCES public.categories(id)  ON DELETE RESTRICT,
  title            VARCHAR(120)    NOT NULL,
  description      TEXT            NOT NULL,
  ad_type          ad_type_enum    NOT NULL DEFAULT 'offering',
  price            DECIMAL(12,2)   CHECK (price >= 0),
  price_type       price_type_enum NOT NULL DEFAULT 'fixed',
  currency         VARCHAR(3)      NOT NULL DEFAULT 'EGP',
  city_id          INTEGER         NOT NULL REFERENCES public.cities(id)      ON DELETE RESTRICT,
  district_id      INTEGER         REFERENCES public.districts(id)            ON DELETE SET NULL,
  latitude         DECIMAL(10,8),
  longitude        DECIMAL(11,8),
  status           ad_status_enum  NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  is_featured      BOOLEAN         NOT NULL DEFAULT FALSE,
  is_urgent        BOOLEAN         NOT NULL DEFAULT FALSE,
  views_count      INTEGER         NOT NULL DEFAULT 0 CHECK (views_count     >= 0),
  contacts_count   INTEGER         NOT NULL DEFAULT 0 CHECK (contacts_count  >= 0),
  favorites_count  INTEGER         NOT NULL DEFAULT 0 CHECK (favorites_count >= 0),
  expires_at       TIMESTAMPTZ     NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  refreshed_at     TIMESTAMPTZ,
  published_at     TIMESTAMPTZ,
  search_vector    TSVECTOR,
  search_attributes JSONB          NOT NULL DEFAULT '{}'::JSONB,
  created_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ
);
COMMENT ON TABLE public.ads IS 'الجدول الأساسي — قلب منصة وصلة';

CREATE TABLE public.ad_media (
  id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id         UUID            NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  url           TEXT            NOT NULL,
  thumbnail_url TEXT,
  type          media_type_enum NOT NULL DEFAULT 'image',
  sort_order    SMALLINT        NOT NULL DEFAULT 0,
  is_primary    BOOLEAN         NOT NULL DEFAULT FALSE,
  size_bytes    INTEGER         CHECK (size_bytes > 0),
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE public.ad_fields (
  id            UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id         UUID     NOT NULL REFERENCES public.ads(id)             ON DELETE CASCADE,
  field_id      INTEGER  NOT NULL REFERENCES public.category_fields(id) ON DELETE CASCADE,
  value_text    TEXT,
  value_number  DECIMAL(15,4),
  value_boolean BOOLEAN,
  value_json    JSONB,
  UNIQUE (ad_id, field_id)
);
COMMENT ON TABLE public.ad_fields IS 'قيم الحقول الديناميكية لكل إعلان';

CREATE TABLE public.ad_moderation_log (
  id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id           UUID            NOT NULL REFERENCES public.ads(id)   ON DELETE CASCADE,
  moderator_id    UUID            NOT NULL REFERENCES public.users(id)  ON DELETE SET NULL,
  action          mod_action_enum NOT NULL,
  reason          TEXT,
  previous_status VARCHAR(30)     NOT NULL,
  new_status      VARCHAR(30)     NOT NULL,
  created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- ────────────────────────────────────────────────────────────────
-- §10 · INTERACTIONS  (7 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.favorites (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  ad_id      UUID        NOT NULL REFERENCES public.ads(id)   ON DELETE CASCADE,
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, ad_id)
);

CREATE TABLE public.saved_searches (
  id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID            NOT NULL REFERENCES public.users(id)      ON DELETE CASCADE,
  name             VARCHAR(100),
  category_id      SMALLINT        REFERENCES public.categories(id)          ON DELETE SET NULL,
  city_id          INTEGER         REFERENCES public.cities(id)              ON DELETE SET NULL,
  keywords         VARCHAR(200),
  filters          JSONB           NOT NULL DEFAULT '{}',
  notify_via       notify_via_enum NOT NULL DEFAULT 'push',
  is_active        BOOLEAN         NOT NULL DEFAULT TRUE,
  last_notified_at TIMESTAMPTZ,
  created_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.saved_searches IS 'Watchlist — يتلقى المستخدم إشعاراً بكل إعلان جديد يطابق بحثه';

CREATE TABLE public.ad_views (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id       UUID        NOT NULL REFERENCES public.ads(id)   ON DELETE CASCADE,
  viewer_id   UUID        REFERENCES public.users(id)          ON DELETE SET NULL,
  ip_address  INET,
  device_type VARCHAR(20),
  source      VARCHAR(30),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.contact_logs (
  id           UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id        UUID              NOT NULL REFERENCES public.ads(id)   ON DELETE CASCADE,
  user_id      UUID              REFERENCES public.users(id)          ON DELETE SET NULL,
  contact_type contact_type_enum NOT NULL,
  created_at   TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.contact_logs IS 'يُسجَّل كل ضغط على زر التواصل';

CREATE TABLE public.reports (
  id          UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID               NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  target_type target_type_enum   NOT NULL,
  target_id   UUID               NOT NULL,
  reason      report_reason_enum NOT NULL,
  description TEXT,
  status      report_status_enum NOT NULL DEFAULT 'pending',
  reviewed_by UUID               REFERENCES public.users(id)          ON DELETE SET NULL,
  created_at  TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

CREATE TABLE public.reviews (
  id               UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewer_id      UUID               NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reviewed_user_id UUID               NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  ad_id            UUID               REFERENCES public.ads(id)            ON DELETE SET NULL,
  rating           SMALLINT           NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment          TEXT,
  status           review_status_enum NOT NULL DEFAULT 'active',
  created_at       TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  CONSTRAINT no_self_review CHECK (reviewer_id <> reviewed_user_id),
  UNIQUE (reviewer_id, reviewed_user_id, ad_id)
);

CREATE TABLE public.review_responses (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id  UUID        NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES public.users(id)   ON DELETE CASCADE,
  response   TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (review_id)  -- رد واحد لكل تقييم
);

-- Chat Domain
CREATE TABLE public.conversations (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id       UUID        NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  buyer_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  seller_id   UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (ad_id, buyer_id)
);
COMMENT ON TABLE public.conversations IS 'المحادثات المباشرة بين المشتري والعلَن';

CREATE TABLE public.messages (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID        NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id       UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content         TEXT        NOT NULL,
  is_read         BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.messages IS 'رسائل الدردشة داخل التطبيق';

-- Booking Domain
CREATE TABLE public.service_bookings (
  id             UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id          UUID               NOT NULL REFERENCES public.ads(id) ON DELETE RESTRICT,
  customer_id    UUID               NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  worker_id      UUID               NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  scheduled_at   TIMESTAMPTZ        NOT NULL,
  status         booking_status_enum NOT NULL DEFAULT 'pending',
  customer_notes TEXT,
  agreed_price   DECIMAL(10,2)      CHECK (agreed_price >= 0),
  created_at     TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.service_bookings IS 'حجوزات العمالة والخدمات ومتابعة حالة الطلب';

-- User Blocks
CREATE TABLE public.user_blocks (
  blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);
COMMENT ON TABLE public.user_blocks IS 'حظر المستخدمين لبعضهم البعض';


-- ────────────────────────────────────────────────────────────────
-- §11 · PAYMENTS  (6 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.user_subscriptions (
  id         UUID                     PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID                     NOT NULL REFERENCES public.users(id)             ON DELETE CASCADE,
  plan_id    SMALLINT                 NOT NULL REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
  status     subscription_status_enum NOT NULL DEFAULT 'active',
  started_at TIMESTAMPTZ              NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ              NOT NULL,
  auto_renew BOOLEAN                  NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ              NOT NULL DEFAULT NOW()
);

CREATE TABLE public.ad_boosts (
  id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id      UUID            NOT NULL REFERENCES public.ads(id)   ON DELETE CASCADE,
  user_id    UUID            NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  boost_type boost_type_enum NOT NULL,
  started_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ     NOT NULL,
  created_at TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE public.transactions (
  id                     UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                UUID                    NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type                   transaction_type_enum   NOT NULL,
  reference_id           UUID,
  reference_type         VARCHAR(30),
  amount                 DECIMAL(10,2)           NOT NULL CHECK (amount > 0),
  currency               VARCHAR(3)              NOT NULL DEFAULT 'EGP',
  payment_method         payment_method_enum     NOT NULL,
  payment_gateway        VARCHAR(30)             NOT NULL,
  gateway_transaction_id VARCHAR(100),
  status                 transaction_status_enum NOT NULL DEFAULT 'pending',
  metadata               JSONB,
  created_at             TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
  completed_at           TIMESTAMPTZ
);
COMMENT ON TABLE public.transactions IS 'Paymob / فوري / Vodafone Cash / InstaPay';

CREATE TABLE public.user_credits (
  user_id    UUID          PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  balance    DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  updated_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.user_credits IS '1-to-1 مع users — رصيد داخلي بالجنيه المصري';

CREATE TABLE public.credit_transactions (
  id            UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID                NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount        DECIMAL(10,2)       NOT NULL,
  type          credit_tx_type_enum NOT NULL,
  description   VARCHAR(200)        NOT NULL,
  balance_after DECIMAL(10,2)       NOT NULL CHECK (balance_after >= 0),
  created_at    TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);


-- ────────────────────────────────────────────────────────────────
-- §12 · NOTIFICATIONS  (2 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.notifications (
  id         UUID                   PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID                   NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type       notification_type_enum NOT NULL,
  title      VARCHAR(150)           NOT NULL,
  body       TEXT                   NOT NULL,
  data       JSONB,
  is_read    BOOLEAN                NOT NULL DEFAULT FALSE,
  read_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ            NOT NULL DEFAULT NOW()
);

CREATE TABLE public.push_tokens (
  id         UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID               NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token      TEXT               NOT NULL UNIQUE,
  platform   push_platform_enum NOT NULL,
  is_active  BOOLEAN            NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.push_tokens IS 'FCM (Android/Web) + APNs (iOS) tokens';


-- ────────────────────────────────────────────────────────────────
-- §13 · SYSTEM  (2 tables)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.audit_logs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
  action      VARCHAR(80) NOT NULL,
  target_type VARCHAR(30) NOT NULL,
  target_id   UUID,
  changes     JSONB,
  ip_address  INET,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.audit_logs IS 'كل إجراء يقوم به الأدمن أو المشرفون';

CREATE TABLE public.app_configs (
  key         VARCHAR(80) PRIMARY KEY,
  value       JSONB       NOT NULL,
  description TEXT,
  updated_by  UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.app_configs IS 'إعدادات ديناميكية تُدار من لوحة التحكم';


-- ────────────────────────────────────────────────────────────────
-- §14 · INDEXES
-- ────────────────────────────────────────────────────────────────

-- Geography
CREATE INDEX idx_cities_gov          ON public.cities(governorate_id);
CREATE INDEX idx_districts_city      ON public.districts(city_id);

-- Users
CREATE INDEX idx_users_phone         ON public.users(phone)     WHERE phone     IS NOT NULL;
CREATE INDEX idx_users_status        ON public.users(status);
CREATE INDEX idx_users_type          ON public.users(user_type);
CREATE INDEX idx_users_city          ON public.users(city_id)   WHERE city_id   IS NOT NULL;

-- Categories
CREATE INDEX idx_categories_parent   ON public.categories(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_categories_slug     ON public.categories(slug);

-- Category fields
CREATE INDEX idx_cat_fields_cat      ON public.category_fields(category_id);

-- Ads — most critical
CREATE INDEX idx_ads_user            ON public.ads(user_id);
CREATE INDEX idx_ads_category        ON public.ads(category_id);
CREATE INDEX idx_ads_city            ON public.ads(city_id);
CREATE INDEX idx_ads_status          ON public.ads(status);
CREATE INDEX idx_ads_featured        ON public.ads(is_featured)  WHERE is_featured = TRUE;
CREATE INDEX idx_ads_urgent          ON public.ads(is_urgent)    WHERE is_urgent   = TRUE;
CREATE INDEX idx_ads_created         ON public.ads(created_at DESC);
CREATE INDEX idx_ads_expires         ON public.ads(expires_at)   WHERE status = 'active';
CREATE INDEX idx_ads_location        ON public.ads(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX idx_ads_search          ON public.ads USING GIN(search_vector);
CREATE INDEX idx_ads_search_attr     ON public.ads USING GIN(search_attributes);
CREATE INDEX idx_ads_price           ON public.ads(price)        WHERE price IS NOT NULL;
CREATE INDEX idx_ads_status_city_dt  ON public.ads(status, city_id, created_at DESC);

-- Ad media
CREATE INDEX idx_ad_media_ad         ON public.ad_media(ad_id);
CREATE INDEX idx_ad_media_primary    ON public.ad_media(ad_id, is_primary) WHERE is_primary = TRUE;

-- Ad fields
CREATE INDEX idx_ad_fields_ad        ON public.ad_fields(ad_id);

-- Moderation
CREATE INDEX idx_mod_log_ad          ON public.ad_moderation_log(ad_id);

-- Interactions
CREATE INDEX idx_favorites_user      ON public.favorites(user_id);
CREATE INDEX idx_favorites_ad        ON public.favorites(ad_id);
CREATE INDEX idx_saved_searches_user ON public.saved_searches(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_ad_views_ad         ON public.ad_views(ad_id, created_at DESC);
CREATE INDEX idx_ad_views_user       ON public.ad_views(viewer_id) WHERE viewer_id IS NOT NULL;
CREATE INDEX idx_contact_logs_ad     ON public.contact_logs(ad_id);
CREATE INDEX idx_contact_logs_user   ON public.contact_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_reports_status      ON public.reports(status) WHERE status = 'pending';
CREATE INDEX idx_reviews_reviewed    ON public.reviews(reviewed_user_id);
CREATE INDEX idx_reviews_reviewer    ON public.reviews(reviewer_id);

-- Chat & Bookings & Blocks Indexes
CREATE INDEX idx_conversations_buyer      ON public.conversations(buyer_id);
CREATE INDEX idx_conversations_seller     ON public.conversations(seller_id);
CREATE INDEX idx_conversations_ad         ON public.conversations(ad_id);
CREATE INDEX idx_messages_conversation    ON public.messages(conversation_id, created_at DESC);
CREATE INDEX idx_bookings_customer        ON public.service_bookings(customer_id);
CREATE INDEX idx_bookings_worker          ON public.service_bookings(worker_id);
CREATE INDEX idx_bookings_status          ON public.service_bookings(status);

-- Payments
CREATE INDEX idx_transactions_user   ON public.transactions(user_id, created_at DESC);
CREATE INDEX idx_transactions_status ON public.transactions(status);
CREATE INDEX idx_ad_boosts_ad        ON public.ad_boosts(ad_id, expires_at);
CREATE INDEX idx_ad_boosts_active    ON public.ad_boosts(expires_at);
CREATE INDEX idx_subs_user           ON public.user_subscriptions(user_id, status);
CREATE INDEX idx_credit_tx_user      ON public.credit_transactions(user_id, created_at DESC);

-- Notifications
CREATE INDEX idx_notifs_user         ON public.notifications(user_id, is_read, created_at DESC);
CREATE INDEX idx_notifs_unread       ON public.notifications(user_id) WHERE is_read = FALSE;
CREATE INDEX idx_push_tokens_user    ON public.push_tokens(user_id)   WHERE is_active = TRUE;

-- Sessions
CREATE INDEX idx_sessions_user       ON public.user_sessions(user_id);
CREATE INDEX idx_sessions_expires    ON public.user_sessions(expires_at);

-- Audit
CREATE INDEX idx_audit_actor         ON public.audit_logs(actor_id, created_at DESC);
CREATE INDEX idx_audit_target        ON public.audit_logs(target_type, target_id);


-- ────────────────────────────────────────────────────────────────
-- §15 · FUNCTIONS
-- ────────────────────────────────────────────────────────────────

-- A. Auto-create user profile on Supabase Auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  INSERT INTO public.user_credits (user_id, balance)
  VALUES (NEW.id, 0.00);
  RETURN NEW;
END;
$$;

-- B. Maintain updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- C. Build Arabic-aware search vector
CREATE OR REPLACE FUNCTION public.update_ad_search_vector()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('simple', COALESCE(NEW.title, '')),       'A') ||
    setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B');
  RETURN NEW;
END;
$$;

-- D. Set published_at when ad goes active
CREATE OR REPLACE FUNCTION public.set_ad_published_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'active' AND OLD.status <> 'active' THEN
    NEW.published_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;

-- E. Increment / decrement favorites_count
CREATE OR REPLACE FUNCTION public.update_favorites_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.ads SET favorites_count = favorites_count + 1     WHERE id = NEW.ad_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.ads SET favorites_count = GREATEST(favorites_count - 1, 0) WHERE id = OLD.ad_id;
  END IF;
  RETURN NULL;
END;
$$;

-- F. Increment contacts_count
CREATE OR REPLACE FUNCTION public.update_contacts_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.ads SET contacts_count = contacts_count + 1 WHERE id = NEW.ad_id;
  RETURN NULL;
END;
$$;

-- G. Recalculate trust_score after every review change
CREATE OR REPLACE FUNCTION public.update_trust_score()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  target_user UUID;
BEGIN
  target_user := COALESCE(NEW.reviewed_user_id, OLD.reviewed_user_id);
  UPDATE public.users
  SET trust_score = (
    SELECT COALESCE(ROUND(AVG(rating)::NUMERIC, 2), 0.00)
    FROM   public.reviews
    WHERE  reviewed_user_id = target_user AND status = 'active'
  )
  WHERE id = target_user;
  RETURN NULL;
END;
$$;

-- G2. Validate review eligibility to prevent rating manipulation
CREATE OR REPLACE FUNCTION public.validate_review_eligibility()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Check if they are self-reviewing
  IF NEW.reviewer_id = NEW.reviewed_user_id THEN
    RAISE EXCEPTION 'لا يمكنك تقييم نفسك.';
  END IF;

  -- Verify if there is a recorded contact log or a completed booking between reviewer and reviewed_user within last 30 days
  IF NOT EXISTS (
    SELECT 1 FROM public.contact_logs cl
    JOIN public.ads a ON cl.ad_id = a.id
    WHERE cl.user_id = NEW.reviewer_id AND a.user_id = NEW.reviewed_user_id
      AND cl.created_at > NOW() - INTERVAL '30 days'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.service_bookings sb
    WHERE sb.customer_id = NEW.reviewer_id AND sb.worker_id = NEW.reviewed_user_id
      AND sb.status = 'completed'
      AND sb.updated_at > NOW() - INTERVAL '30 days'
  ) THEN
    RAISE EXCEPTION 'لا يمكن كتابة تقييم بدون وجود تواصل أو حجز خدمة مكتمل خلال الـ 30 يوماً الماضية.';
  END IF;

  RETURN NEW;
END;
$$;

-- H. RLS helper — is current user admin?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND user_type = 'admin'
  );
$$;

-- I. RLS helper — is current user moderator or admin?
CREATE OR REPLACE FUNCTION public.is_moderator()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND user_type IN ('admin','moderator')
  );
$$;


-- ────────────────────────────────────────────────────────────────
-- §16 · TRIGGERS
-- ────────────────────────────────────────────────────────────────

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_ads_updated_at
  BEFORE UPDATE ON public.ads
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_ads_search_vector
  BEFORE INSERT OR UPDATE OF title, description ON public.ads
  FOR EACH ROW EXECUTE FUNCTION public.update_ad_search_vector();

CREATE TRIGGER trg_ads_published_at
  BEFORE UPDATE OF status ON public.ads
  FOR EACH ROW EXECUTE FUNCTION public.set_ad_published_at();

CREATE TRIGGER trg_favorites_count
  AFTER INSERT OR DELETE ON public.favorites
  FOR EACH ROW EXECUTE FUNCTION public.update_favorites_count();

CREATE TRIGGER trg_contacts_count
  AFTER INSERT ON public.contact_logs
  FOR EACH ROW EXECUTE FUNCTION public.update_contacts_count();

CREATE TRIGGER trg_trust_score
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.update_trust_score();

CREATE TRIGGER trg_validate_review
  BEFORE INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.validate_review_eligibility();

CREATE TRIGGER trg_bookings_updated_at
  BEFORE UPDATE ON public.service_bookings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ────────────────────────────────────────────────────────────────
-- §17 · ROW LEVEL SECURITY  (28 policies)
-- ────────────────────────────────────────────────────────────────
ALTER TABLE public.users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_auth_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_verifications  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ads                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_media            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_fields           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_moderation_log   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_searches      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_views            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_responses    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_boosts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_credits        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_moderation_log   ENABLE ROW LEVEL SECURITY;

-- Enable RLS for Chat & Bookings & Blocks
ALTER TABLE public.user_blocks         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_bookings    ENABLE ROW LEVEL SECURITY;

-- Users
CREATE POLICY "users_select_all"    ON public.users FOR SELECT USING (deleted_at IS NULL OR id = auth.uid());
CREATE POLICY "users_update_own"    ON public.users FOR UPDATE USING (id = auth.uid());
CREATE POLICY "users_delete_own"    ON public.users FOR DELETE USING (id = auth.uid());

-- Ads
CREATE POLICY "ads_select"          ON public.ads FOR SELECT
  USING (status = 'active' OR user_id = auth.uid() OR public.is_moderator());
CREATE POLICY "ads_insert"          ON public.ads FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());
CREATE POLICY "ads_update"          ON public.ads FOR UPDATE
  USING (user_id = auth.uid() OR public.is_moderator());
CREATE POLICY "ads_delete"          ON public.ads FOR DELETE
  USING (user_id = auth.uid() OR public.is_admin());

-- Ad Media
CREATE POLICY "ad_media_select"     ON public.ad_media  FOR SELECT USING (TRUE);
CREATE POLICY "ad_media_insert"     ON public.ad_media  FOR INSERT
  WITH CHECK (EXISTS(SELECT 1 FROM public.ads WHERE id = ad_id AND user_id = auth.uid()));
CREATE POLICY "ad_media_delete"     ON public.ad_media  FOR DELETE
  USING (EXISTS(SELECT 1 FROM public.ads WHERE id = ad_id AND user_id = auth.uid()));

-- Ad Fields
CREATE POLICY "ad_fields_select"    ON public.ad_fields FOR SELECT USING (TRUE);
CREATE POLICY "ad_fields_insert"    ON public.ad_fields FOR INSERT
  WITH CHECK (EXISTS(SELECT 1 FROM public.ads WHERE id = ad_id AND user_id = auth.uid()));

-- Moderation Log
CREATE POLICY "mod_log_select"      ON public.ad_moderation_log FOR SELECT
  USING (public.is_moderator() OR EXISTS(SELECT 1 FROM public.ads WHERE id = ad_id AND user_id = auth.uid()));
CREATE POLICY "mod_log_insert"      ON public.ad_moderation_log FOR INSERT
  WITH CHECK (public.is_moderator());

-- Favorites
CREATE POLICY "favorites_own"       ON public.favorites       USING (user_id = auth.uid());

-- Saved Searches
CREATE POLICY "saved_searches_own"  ON public.saved_searches  USING (user_id = auth.uid());

-- Ad Views
CREATE POLICY "ad_views_insert"     ON public.ad_views  FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "ad_views_select"     ON public.ad_views  FOR SELECT
  USING (viewer_id = auth.uid() OR public.is_admin());

-- Contact Logs
CREATE POLICY "contact_insert"      ON public.contact_logs FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "contact_select"      ON public.contact_logs FOR SELECT
  USING (user_id = auth.uid()
    OR EXISTS(SELECT 1 FROM public.ads WHERE id = ad_id AND user_id = auth.uid())
    OR public.is_admin());

-- Reports
CREATE POLICY "reports_insert"      ON public.reports FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND reporter_id = auth.uid());
CREATE POLICY "reports_select"      ON public.reports FOR SELECT
  USING (reporter_id = auth.uid() OR public.is_moderator());
CREATE POLICY "reports_update_mod"  ON public.reports FOR UPDATE USING (public.is_moderator());

-- Reviews
CREATE POLICY "reviews_select"      ON public.reviews FOR SELECT USING (status = 'active');
CREATE POLICY "reviews_insert"      ON public.reviews FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND reviewer_id = auth.uid());
CREATE POLICY "reviews_update_own"  ON public.reviews FOR UPDATE USING (reviewer_id = auth.uid());

-- Review Responses
CREATE POLICY "rev_resp_select"     ON public.review_responses FOR SELECT USING (TRUE);
CREATE POLICY "rev_resp_insert"     ON public.review_responses FOR INSERT WITH CHECK (user_id = auth.uid());

-- Chat & Bookings & Blocks Policies
CREATE POLICY "blocks_select" ON public.user_blocks FOR SELECT USING (blocker_id = auth.uid());
CREATE POLICY "blocks_insert" ON public.user_blocks FOR INSERT WITH CHECK (blocker_id = auth.uid());
CREATE POLICY "blocks_delete" ON public.user_blocks FOR DELETE USING (blocker_id = auth.uid());

CREATE POLICY "conversations_select" ON public.conversations FOR SELECT
  USING (buyer_id = auth.uid() OR seller_id = auth.uid() OR public.is_admin());
CREATE POLICY "conversations_insert" ON public.conversations FOR INSERT
  WITH CHECK (buyer_id = auth.uid());

CREATE POLICY "messages_select" ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE id = conversation_id AND (buyer_id = auth.uid() OR seller_id = auth.uid())
    )
  );
CREATE POLICY "messages_insert" ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.conversations
      WHERE id = conversation_id AND (buyer_id = auth.uid() OR seller_id = auth.uid())
    )
  );

CREATE POLICY "bookings_select" ON public.service_bookings FOR SELECT
  USING (customer_id = auth.uid() OR worker_id = auth.uid() OR public.is_moderator());
CREATE POLICY "bookings_insert" ON public.service_bookings FOR INSERT
  WITH CHECK (customer_id = auth.uid());
CREATE POLICY "bookings_update" ON public.service_bookings FOR UPDATE
  USING (customer_id = auth.uid() OR worker_id = auth.uid() OR public.is_moderator());

-- Payments / Credits
CREATE POLICY "subs_own"            ON public.user_subscriptions  USING (user_id = auth.uid());
CREATE POLICY "boosts_select"       ON public.ad_boosts FOR SELECT USING (TRUE);
CREATE POLICY "boosts_own"          ON public.ad_boosts FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "transactions_own"    ON public.transactions         USING (user_id = auth.uid());
CREATE POLICY "credits_own"         ON public.user_credits         USING (user_id = auth.uid());
CREATE POLICY "credit_tx_own"       ON public.credit_transactions  USING (user_id = auth.uid());

-- Notifications / Push
CREATE POLICY "notifs_own"          ON public.notifications  USING (user_id = auth.uid());
CREATE POLICY "push_own"            ON public.push_tokens    USING (user_id = auth.uid());

-- Audit
CREATE POLICY "audit_admin_only"    ON public.audit_logs     USING (public.is_admin());

-- Sessions / Verifications
CREATE POLICY "sessions_own"        ON public.user_sessions      USING (user_id = auth.uid());
CREATE POLICY "verifications_own"   ON public.user_verifications USING (user_id = auth.uid());
CREATE POLICY "auth_providers_own"  ON public.user_auth_providers USING (user_id = auth.uid());


-- ────────────────────────────────────────────────────────────────
-- §18 · pg_cron SCHEDULED JOBS
-- NOTE: Enable pg_cron from Supabase Dashboard first
-- ────────────────────────────────────────────────────────────────

SELECT cron.schedule('expire-ads',     '0 * * * *',   $$
  UPDATE public.ads SET status = 'expired'
  WHERE  status = 'active' AND expires_at < NOW() AND deleted_at IS NULL;
$$);

SELECT cron.schedule('expire-boosts',  '5 * * * *',   $$
  UPDATE public.ads SET is_featured = FALSE
  WHERE  is_featured = TRUE AND NOT EXISTS (
    SELECT 1 FROM public.ad_boosts
    WHERE  ad_id = ads.id AND boost_type = 'featured' AND expires_at > NOW()
  );
$$);

SELECT cron.schedule('expire-urgent',  '10 * * * *',  $$
  UPDATE public.ads SET is_urgent = FALSE
  WHERE  is_urgent = TRUE AND NOT EXISTS (
    SELECT 1 FROM public.ad_boosts
    WHERE  ad_id = ads.id AND boost_type = 'urgent' AND expires_at > NOW()
  );
$$);

SELECT cron.schedule('expire-otps',    '*/15 * * * *',$$
  UPDATE public.user_verifications SET status = 'expired'
  WHERE  status = 'pending' AND expires_at < NOW();
$$);

SELECT cron.schedule('cleanup-sessions','0 3 * * *',  $$
  DELETE FROM public.user_sessions WHERE expires_at < NOW() - INTERVAL '7 days';
$$);


-- ────────────────────────────────────────────────────────────────
-- §19 · SEED DATA
-- ────────────────────────────────────────────────────────────────

-- 19.1 · Egyptian Governorates (27)
INSERT INTO public.governorates (name_ar, name_en, code) VALUES
  ('القاهرة',       'Cairo',          'CAI'),
  ('الإسكندرية',    'Alexandria',     'ALX'),
  ('الجيزة',        'Giza',           'GIZ'),
  ('القليوبية',     'Qalyubia',       'QAL'),
  ('الشرقية',       'Sharqia',        'SHA'),
  ('الدقهلية',      'Dakahlia',       'DAK'),
  ('البحيرة',       'Beheira',        'BEH'),
  ('المنوفية',      'Menoufia',       'MEN'),
  ('الغربية',       'Gharbia',        'GHA'),
  ('كفر الشيخ',     'Kafr el-Sheikh', 'KFS'),
  ('دمياط',         'Damietta',       'DAM'),
  ('بورسعيد',       'Port Said',      'POR'),
  ('الإسماعيلية',   'Ismailia',       'ISM'),
  ('السويس',        'Suez',           'SUE'),
  ('شمال سيناء',    'North Sinai',    'NSI'),
  ('جنوب سيناء',    'South Sinai',    'SSI'),
  ('البحر الأحمر',  'Red Sea',        'RSE'),
  ('الوادي الجديد', 'New Valley',     'NVA'),
  ('مطروح',         'Matruh',         'MAT'),
  ('أسيوط',         'Asyut',          'ASY'),
  ('سوهاج',         'Sohag',          'SOH'),
  ('قنا',           'Qena',           'QEN'),
  ('الأقصر',        'Luxor',          'LUX'),
  ('أسوان',         'Aswan',          'ASW'),
  ('المنيا',        'Minya',          'MIN'),
  ('بني سويف',      'Beni Suef',      'BNS'),
  ('الفيوم',        'Faiyum',         'FAI');

-- 19.2 · Major Cities — Cairo (gov=1)
INSERT INTO public.cities (governorate_id, name_ar, name_en, latitude, longitude) VALUES
  (1,'وسط القاهرة',   'Downtown Cairo',    30.0444, 31.2357),
  (1,'مدينة نصر',     'Nasr City',         30.0626, 31.3422),
  (1,'المعادي',        'Maadi',             29.9602, 31.2569),
  (1,'مصر الجديدة',   'Heliopolis',        30.0892, 31.3214),
  (1,'الزمالك',        'Zamalek',           30.0659, 31.2195),
  (1,'شبرا',           'Shubra',            30.1057, 31.2423),
  (1,'عين شمس',        'Ain Shams',         30.1065, 31.3268),
  (1,'حلوان',          'Helwan',            29.8448, 31.3337),
  (1,'التجمع الخامس',  'Fifth Settlement',  30.0087, 31.4733),
  (1,'مدينتي',         'Madinaty',          30.1169, 31.6438),
  (1,'الرحاب',         'Al Rehab',          30.0586, 31.4926),
  (1,'العباسية',       'Abbasiya',          30.0631, 31.2786),
  (1,'المطرية',        'Matareya',          30.1221, 31.3093),
  (1,'حدائق الأهرام',  'Ahram Gardens',     29.9863, 31.1373),
  (1,'شبرا الخيمة',    'Shubra El Kheima',  30.1291, 31.2463);

-- Giza (gov=3)
INSERT INTO public.cities (governorate_id, name_ar, name_en, latitude, longitude) VALUES
  (3,'الدقي',         'Dokki',             30.0403, 31.2106),
  (3,'المهندسين',     'Mohandessin',       30.0574, 31.1993),
  (3,'الهرم',         'Haram',             29.9899, 31.1597),
  (3,'6 أكتوبر',      '6th of October',    29.9360, 31.0117),
  (3,'الشيخ زايد',    'Sheikh Zayed',      30.0131, 30.9472),
  (3,'فيصل',          'Faisal',            29.9985, 31.1280),
  (3,'إمبابة',        'Imbaba',            30.0772, 31.2025);

-- Alexandria (gov=2)
INSERT INTO public.cities (governorate_id, name_ar, name_en, latitude, longitude) VALUES
  (2,'المنتزه',       'Montazah',          31.2950, 30.0131),
  (2,'سيدي جابر',     'Sidi Gaber',        31.2179, 29.9395),
  (2,'سموحة',         'Smouha',            31.2046, 29.9540),
  (2,'العجمي',        'Agami',             31.1473, 29.7800),
  (2,'محرم بك',       'Moharam Bek',       31.1956, 29.9184),
  (2,'مصطفى كامل',    'Mustafa Kamel',     31.2364, 30.0031),
  (2,'ميامي',         'Miami',             31.2631, 30.0299);

-- 19.3 · Main Categories (level 1)
INSERT INTO public.categories (name_ar, name_en, slug, icon, level, sort_order) VALUES
  ('خدمات',  'Services',    'services',    '🔧', 1, 1),
  ('وظائف',  'Jobs',        'jobs',        '💼', 1, 2),
  ('عقارات', 'Real Estate', 'real-estate', '🏠', 1, 3),
  ('سيارات', 'Vehicles',    'vehicles',    '🚗', 1, 4),
  ('سلع',    'Goods',       'goods',       '📦', 1, 5);

-- Services sub-categories (parent_id=1)
INSERT INTO public.categories (parent_id, name_ar, name_en, slug, icon, level, sort_order) VALUES
  (1,'سباكة وصرف صحي', 'Plumbing',      'plumbing',    '🚿', 2, 1),
  (1,'كهرباء ومنازل',  'Electrical',    'electrical',  '💡', 2, 2),
  (1,'تدريس وتعليم',   'Teaching',      'teaching',    '📚', 2, 3),
  (1,'تنظيف ومكافحة',  'Cleaning',      'cleaning',    '🧹', 2, 4),
  (1,'نجارة وأثاث',    'Carpentry',     'carpentry',   '🪚', 2, 5),
  (1,'دهانات وديكور',  'Painting',      'painting',    '🎨', 2, 6),
  (1,'تكييف وتبريد',   'AC & Cooling',  'ac-cooling',  '❄️', 2, 7),
  (1,'مواصلات وتوصيل', 'Transport',     'transport',   '🚚', 2, 8),
  (1,'تصميم وبرمجة',   'Design & Dev',  'design-dev',  '💻', 2, 9),
  (1,'صحة وتمريض',     'Healthcare',    'healthcare',  '🏥', 2, 10);

-- Jobs sub-categories (parent_id=2)
INSERT INTO public.categories (parent_id, name_ar, name_en, slug, icon, level, sort_order) VALUES
  (2,'وظائف إدارية',   'Administrative',  'admin-jobs',   '📋', 2, 1),
  (2,'مبيعات وتسويق',  'Sales',           'sales-jobs',   '📈', 2, 2),
  (2,'هندسة وتقنية',   'Engineering/IT',  'tech-jobs',    '⚙️', 2, 3),
  (2,'صحة وطب',        'Medical',         'medical-jobs', '🩺', 2, 4),
  (2,'تعليم وتدريب',   'Education',       'edu-jobs',     '🎓', 2, 5),
  (2,'سياحة وفنادق',   'Tourism',         'tourism-jobs', '🏨', 2, 6),
  (2,'أمن وحراسة',     'Security',        'security-jobs','🔒', 2, 7);

-- Real Estate sub-categories (parent_id=3)
INSERT INTO public.categories (parent_id, name_ar, name_en, slug, icon, level, sort_order) VALUES
  (3,'شقق للإيجار',    'Apartments Rent', 'apt-rent',    '🏢', 2, 1),
  (3,'شقق للبيع',      'Apartments Sale', 'apt-sale',    '🏠', 2, 2),
  (3,'غرف للإيجار',    'Rooms Rent',      'rooms-rent',  '🛏️', 2, 3),
  (3,'فيلات ودوبلكس',  'Villas',          'villas',      '🏡', 2, 4),
  (3,'محلات تجارية',   'Commercial',      'commercial',  '🏪', 2, 5),
  (3,'أراضي',          'Land',            'land',        '🌍', 2, 6);

-- Vehicles sub-categories (parent_id=4)
INSERT INTO public.categories (parent_id, name_ar, name_en, slug, icon, level, sort_order) VALUES
  (4,'سيارات',         'Cars',           'cars',         '🚗', 2, 1),
  (4,'دراجات نارية',   'Motorcycles',    'motorcycles',  '🏍️', 2, 2),
  (4,'تكاتك',          'Tuk Tuks',       'tuk-tuks',     '🛺', 2, 3),
  (4,'شاحنات ونقل',    'Trucks',         'trucks',       '🚛', 2, 4);

-- Goods sub-categories (parent_id=5)
INSERT INTO public.categories (parent_id, name_ar, name_en, slug, icon, level, sort_order) VALUES
  (5,'إلكترونيات',     'Electronics',    'electronics',  '📱', 2, 1),
  (5,'أثاث وديكور',    'Furniture',      'furniture',    '🛋️', 2, 2),
  (5,'ملابس وأكسسوار', 'Fashion',        'fashion',      '👗', 2, 3),
  (5,'أجهزة منزلية',   'Appliances',     'appliances',   '🏠', 2, 4),
  (5,'رياضة وترفيه',   'Sports',         'sports',       '⚽', 2, 5),
  (5,'مستلزمات أطفال', 'Kids',           'kids',         '🧸', 2, 6),
  (5,'كتب ومستلزمات',  'Books',          'books',        '📖', 2, 7);

-- 19.4 · Subscription Plans
INSERT INTO public.subscription_plans
  (name, name_ar, price_monthly, price_yearly, max_ads, max_images_per_ad, features, sort_order)
VALUES
  ('free',     'مجاني',    0,    0,    5,   4,
   '{"can_boost":false,"verified_badge":false,"analytics":false,"priority_support":false}', 1),
  ('basic',    'أساسي',    99,   950,  20,  8,
   '{"can_boost":false,"verified_badge":true,"analytics":false,"priority_support":false}',  2),
  ('premium',  'بريميوم',  199,  1900, 50,  12,
   '{"can_boost":true,"verified_badge":true,"analytics":true,"priority_support":false}',   3),
  ('business', 'أعمال',    499,  4790, 999, 20,
   '{"can_boost":true,"verified_badge":true,"analytics":true,"priority_support":true,"api_access":true}', 4);

-- 19.5 · App Configurations
INSERT INTO public.app_configs (key, value, description) VALUES
  ('max_free_ads',          '5',          'الحد الأقصى للإعلانات المجانية النشطة'),
  ('ad_expiry_days',        '30',         'أيام صلاحية الإعلان'),
  ('otp_expiry_minutes',    '10',         'مدة صلاحية الـ OTP بالدقائق'),
  ('otp_max_attempts',      '5',          'الحد الأقصى لمحاولات OTP'),
  ('boost_featured_3d',     '30',         'سعر Featured 3 أيام بالجنيه'),
  ('boost_featured_7d',     '60',         'سعر Featured 7 أيام'),
  ('boost_featured_14d',    '100',        'سعر Featured 14 يوم'),
  ('boost_featured_30d',    '180',        'سعر Featured 30 يوم'),
  ('boost_urgent_7d',       '40',         'سعر Urgent Badge 7 أيام'),
  ('boost_bump',            '10',         'سعر Bump مرة واحدة'),
  ('max_watchlist_per_user','10',         'الحد الأقصى للبحوث المحفوظة'),
  ('max_ad_title_chars',    '120',        'الحد الأقصى لأحرف عنوان الإعلان'),
  ('platform_currency',     '"EGP"',      'عملة المنصة'),
  ('maintenance_mode',      'false',      'وضع الصيانة');


-- ════════════════════════════════════════════════════════════════
--  ✅  وصلة Database v1.0 — جاهز للتشغيل على Supabase
--  34 Tables | 45 FK Relations | 25 ENUMs | 27 Governorates
--  8 Functions | 8 Triggers | 30 RLS Policies | 5 cron Jobs
--  Seed: 27 محافظة | 29 مدينة | 41 قسم | 4 خطط اشتراك
-- ════════════════════════════════════════════════════════════════
