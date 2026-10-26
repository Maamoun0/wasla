-- ================================================================
-- Wasla baseline schema.
-- Generated from the schema the legacy SQL scripts produced (see
-- scripts/db/legacy_reconstruction.txt, applied without the leading
-- DROP SCHEMA), dumped with pg_dump --schema-only --no-owner
-- --no-privileges, plus reference data and the objects that live outside
-- public (auth trigger, storage buckets/policies, cron jobs).
-- It intentionally reproduces that state as-is, defects included; later
-- migrations fix them. Do not edit; add a new migration instead.
-- ================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm   WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS unaccent  WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgis   WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS vector    WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pgcrypto  WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron;

--
-- PostgreSQL database dump
--


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: ad_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ad_status_enum AS ENUM (
    'pending',
    'active',
    'paused',
    'rejected',
    'expired',
    'deleted',
    'sold'
);


--
-- Name: ad_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ad_type_enum AS ENUM (
    'offering',
    'seeking'
);


--
-- Name: auth_provider_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.auth_provider_enum AS ENUM (
    'google',
    'facebook',
    'apple'
);


--
-- Name: booking_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.booking_status_enum AS ENUM (
    'pending',
    'accepted',
    'in_progress',
    'completed',
    'cancelled'
);


--
-- Name: boost_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.boost_type_enum AS ENUM (
    'featured',
    'urgent',
    'bump'
);


--
-- Name: contact_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contact_type_enum AS ENUM (
    'phone',
    'whatsapp',
    'email'
);


--
-- Name: credit_tx_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.credit_tx_type_enum AS ENUM (
    'purchase',
    'boost_spend',
    'refund',
    'bonus'
);


--
-- Name: field_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.field_type_enum AS ENUM (
    'text',
    'number',
    'select',
    'boolean',
    'range'
);


--
-- Name: media_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.media_type_enum AS ENUM (
    'image',
    'video'
);


--
-- Name: mod_action_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mod_action_enum AS ENUM (
    'approved',
    'rejected',
    'flagged',
    'suspended',
    'restored'
);


--
-- Name: notification_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.notification_type_enum AS ENUM (
    'saved_search_match',
    'ad_approved',
    'ad_rejected',
    'new_review',
    'boost_expiring',
    'system'
);


--
-- Name: notify_via_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.notify_via_enum AS ENUM (
    'push',
    'email',
    'both'
);


--
-- Name: payment_method_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_method_enum AS ENUM (
    'card',
    'fawry',
    'instapay',
    'vodafone_cash'
);


--
-- Name: price_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.price_type_enum AS ENUM (
    'fixed',
    'negotiable',
    'free',
    'per_hour',
    'per_month'
);


--
-- Name: push_platform_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.push_platform_enum AS ENUM (
    'android',
    'ios',
    'web'
);


--
-- Name: report_reason_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.report_reason_enum AS ENUM (
    'fraud',
    'duplicate',
    'inappropriate',
    'wrong_category',
    'spam',
    'other'
);


--
-- Name: report_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.report_status_enum AS ENUM (
    'pending',
    'reviewed',
    'resolved',
    'dismissed'
);


--
-- Name: review_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.review_status_enum AS ENUM (
    'active',
    'hidden',
    'deleted'
);


--
-- Name: subscription_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_status_enum AS ENUM (
    'active',
    'expired',
    'cancelled',
    'trial'
);


--
-- Name: target_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.target_type_enum AS ENUM (
    'ad',
    'user'
);


--
-- Name: transaction_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.transaction_status_enum AS ENUM (
    'pending',
    'completed',
    'failed',
    'refunded'
);


--
-- Name: transaction_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.transaction_type_enum AS ENUM (
    'subscription',
    'ad_boost',
    'credit_purchase'
);


--
-- Name: user_activity_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_activity_type_enum AS ENUM (
    'login_success',
    'login_failed',
    'otp_requested',
    'payment_attempted',
    'payment_completed',
    'ad_published',
    'account_deletion_requested'
);


--
-- Name: user_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_status_enum AS ENUM (
    'active',
    'suspended',
    'deleted',
    'pending_verification',
    'banned'
);


--
-- Name: user_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_type_enum AS ENUM (
    'regular',
    'business',
    'moderator',
    'admin'
);


--
-- Name: verification_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.verification_status_enum AS ENUM (
    'pending',
    'approved',
    'rejected',
    'expired'
);


--
-- Name: verification_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.verification_type_enum AS ENUM (
    'phone_otp',
    'email_token',
    'national_id'
);


--
-- Name: advanced_search_ads(text, integer, integer, numeric, numeric, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.advanced_search_ads(p_query text, p_category_id integer DEFAULT NULL::integer, p_city_id integer DEFAULT NULL::integer, p_min_price numeric DEFAULT NULL::numeric, p_max_price numeric DEFAULT NULL::numeric, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, title text, description text, price numeric, price_type public.price_type_enum, city_name_ar text, category_name_ar text, primary_image_url text, blurhash text, rank real, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.title,
        a.description,
        a.price,
        a.price_type,
        ci.name_ar as city_name_ar,
        ca.name_ar as category_name_ar,
        m.url as primary_image_url,
        m.blurhash,
        ts_rank(a.search_vector, plainto_tsquery('arabic', p_query)) as rank,
        a.created_at
    FROM 
        public.ads a
    LEFT JOIN public.cities ci ON a.city_id = ci.id
    LEFT JOIN public.categories ca ON a.category_id = ca.id
    LEFT JOIN public.ad_media m ON a.id = m.ad_id AND m.is_primary = TRUE
    WHERE 
        (p_query IS NULL OR p_query = '' OR a.search_vector @@ plainto_tsquery('arabic', p_query))
        AND (p_category_id IS NULL OR a.category_id = p_category_id)
        AND (p_city_id IS NULL OR a.city_id = p_city_id)
        AND (p_min_price IS NULL OR a.price >= p_min_price)
        AND (p_max_price IS NULL OR a.price <= p_max_price)
        AND a.status = 'active'
    ORDER BY 
        rank DESC, 
        a.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;


--
-- Name: calculate_user_trust_score(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_user_trust_score(p_user_id uuid) RETURNS numeric
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_score DECIMAL := 0;
    v_kyc_bonus INT := 0;
    v_review_avg DECIMAL := 0;
    v_review_count INT := 0;
    v_ad_count INT := 0;
    v_social_count INT := 0;
BEGIN
    -- A. KYC Bonus (20 points)
    SELECT CASE WHEN is_id_verified THEN 20 ELSE 0 END INTO v_kyc_bonus
    FROM public.users WHERE id = p_user_id;
    v_score := v_score + v_kyc_bonus;

    -- B. Reviews Impact (Max 50 points)
    SELECT COALESCE(AVG(rating), 0), COUNT(*) INTO v_review_avg, v_review_count
    FROM public.reviews WHERE reviewed_user_id = p_user_id AND status = 'active';
    
    -- Formula: (Avg Rating / 5) * 50, but weighted by count (need at least 3 reviews for full weight)
    IF v_review_count > 0 THEN
        v_score := v_score + (v_review_avg / 5.0) * LEAST(v_review_count * 10, 50);
    END IF;

    -- C. Social/Activity Impact (Max 30 points)
    SELECT COUNT(*) INTO v_social_count FROM public.user_auth_providers WHERE user_id = p_user_id;
    v_score := v_score + LEAST(v_social_count * 10, 20);
    
    SELECT COUNT(*) INTO v_ad_count FROM public.ads WHERE user_id = p_user_id AND status = 'active';
    v_score := v_score + LEAST(v_ad_count * 2, 10);

    RETURN LEAST(v_score, 100);
END;
$$;


--
-- Name: create_ad_transaction(uuid, character varying, integer, character varying, text, public.ad_type_enum, numeric, public.price_type_enum, integer, integer, numeric, numeric, character varying, text, smallint, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_ad_transaction(p_user_id uuid, p_temp_draft_id character varying, p_category_id integer, p_title character varying, p_description text, p_ad_type public.ad_type_enum, p_price numeric, p_price_type public.price_type_enum, p_city_id integer, p_district_id integer, p_latitude numeric, p_longitude numeric, p_ai_risk_level character varying, p_ai_review_notes text, p_ai_layer_used smallint, p_images jsonb, p_fields jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_ad_id UUID;
  v_img JSONB;
  v_field JSONB;
BEGIN
  -- Insert into ads table
  INSERT INTO public.ads (
    user_id,
    temp_draft_id,
    category_id,
    title,
    description,
    ad_type,
    price,
    price_type,
    city_id,
    district_id,
    latitude,
    longitude,
    status
  ) VALUES (
    p_user_id,
    p_temp_draft_id,
    p_category_id,
    p_title,
    p_description,
    p_ad_type,
    p_price,
    p_price_type,
    p_city_id,
    p_district_id,
    p_latitude,
    p_longitude,
    'pending'::public.ad_status_enum
  ) RETURNING id INTO v_ad_id;

  -- Insert images into ad_media table
  IF p_images IS NOT NULL AND jsonb_array_length(p_images) > 0 THEN
    FOR v_img IN SELECT * FROM jsonb_array_elements(p_images) LOOP
      INSERT INTO public.ad_media (
        ad_id,
        url,
        type,
        sort_order,
        is_primary
      ) VALUES (
        v_ad_id,
        v_img->>'url',
        'image'::public.media_type_enum,
        (v_img->>'sort_order')::SMALLINT,
        COALESCE((v_img->>'is_primary')::BOOLEAN, false)
      );
    END LOOP;
  END IF;

  -- Insert dynamic fields into ad_fields table
  IF p_fields IS NOT NULL AND jsonb_array_length(p_fields) > 0 THEN
    FOR v_field IN SELECT * FROM jsonb_array_elements(p_fields) LOOP
      INSERT INTO public.ad_fields (
        ad_id,
        field_id,
        value_text,
        value_number,
        value_boolean,
        value_json
      ) VALUES (
        v_ad_id,
        (v_field->>'field_id')::INTEGER,
        v_field->>'value_text',
        (v_field->>'value_number')::DECIMAL(15,4),
        (v_field->>'value_boolean')::BOOLEAN,
        (v_field->'value_json')
      );
    END LOOP;
  END IF;

  -- Store AI review attributes in search_attributes JSONB field
  UPDATE public.ads
  SET search_attributes = jsonb_build_object(
    'ai_risk_level', p_ai_risk_level,
    'ai_review_notes', p_ai_review_notes
  ),
  ai_layer_used = p_ai_layer_used
  WHERE id = v_ad_id;

  RETURN v_ad_id;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    category_id smallint NOT NULL,
    title character varying(120) NOT NULL,
    description text NOT NULL,
    ad_type public.ad_type_enum DEFAULT 'offering'::public.ad_type_enum NOT NULL,
    price numeric(12,2),
    price_type public.price_type_enum DEFAULT 'fixed'::public.price_type_enum NOT NULL,
    currency character varying(3) DEFAULT 'EGP'::character varying NOT NULL,
    city_id integer NOT NULL,
    district_id integer,
    latitude numeric(10,8),
    longitude numeric(11,8),
    status public.ad_status_enum DEFAULT 'pending'::public.ad_status_enum NOT NULL,
    rejection_reason text,
    is_featured boolean DEFAULT false NOT NULL,
    is_urgent boolean DEFAULT false NOT NULL,
    views_count integer DEFAULT 0 NOT NULL,
    contacts_count integer DEFAULT 0 NOT NULL,
    favorites_count integer DEFAULT 0 NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '30 days'::interval) NOT NULL,
    refreshed_at timestamp with time zone,
    published_at timestamp with time zone,
    search_vector tsvector,
    search_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    embedding public.vector(1536),
    temp_draft_id character varying(50),
    ai_layer_used smallint,
    is_hidden boolean DEFAULT false,
    location_point public.geography(Point,4326),
    CONSTRAINT ads_contacts_count_check CHECK ((contacts_count >= 0)),
    CONSTRAINT ads_favorites_count_check CHECK ((favorites_count >= 0)),
    CONSTRAINT ads_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT ads_views_count_check CHECK ((views_count >= 0))
);


--
-- Name: get_ads_near_me(numeric, numeric, double precision, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_ads_near_me(p_lat numeric, p_lng numeric, p_radius_meters double precision DEFAULT 5000, p_limit integer DEFAULT 20) RETURNS SETOF public.ads
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.ads
    WHERE 
        status = 'active'
        AND ST_DWithin(
            location_point, 
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, 
            p_radius_meters
        )
    ORDER BY location_point <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    LIMIT p_limit;
END;
$$;


--
-- Name: get_market_price_stats(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_market_price_stats(p_category_id integer, p_city_id integer DEFAULT NULL::integer) RETURNS TABLE(avg_price numeric, min_price numeric, max_price numeric, ad_count integer, price_label text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            AVG(price)::DECIMAL as avg_p,
            MIN(price)::DECIMAL as min_p,
            MAX(price)::DECIMAL as max_p,
            COUNT(*)::INT as cnt
        FROM public.ads
        WHERE category_id = p_category_id
          AND (p_city_id IS NULL OR city_id = p_city_id)
          AND status = 'active'
          AND price > 0
    )
    SELECT 
        avg_p,
        min_p,
        max_p,
        cnt,
        'Based on ' || cnt || ' similar items in your area'
    FROM stats;
END;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  _phone TEXT;
  _email TEXT;
  _full_name TEXT;
BEGIN
  _phone     := NEW.phone;
  _email     := NEW.email;
  _full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    ''
  );

  INSERT INTO public.users (id, email, phone, full_name)
  VALUES (NEW.id, _email, _phone, _full_name)
  ON CONFLICT (id) DO UPDATE SET
    email      = EXCLUDED.email,
    phone      = COALESCE(EXCLUDED.phone, public.users.phone),
    full_name  = CASE 
                   WHEN public.users.full_name = '' THEN EXCLUDED.full_name 
                   ELSE public.users.full_name 
                 END,
    updated_at = NOW();

  INSERT INTO public.user_credits (user_id, balance)
  VALUES (NEW.id, 0.00)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;


--
-- Name: handle_report(uuid, uuid, public.report_status_enum, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_report(p_report_id uuid, p_moderator_id uuid, p_status public.report_status_enum, p_action_taken text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_reporter_id UUID;
    v_target_id UUID;
    v_target_type target_type_enum;
BEGIN
    -- 1. Fetch report details
    SELECT reporter_id, target_id, target_type INTO v_reporter_id, v_target_id, v_target_type
    FROM public.reports
    WHERE id = p_report_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البلاغ غير موجود');
    END IF;

    -- 2. Update the Report Record
    UPDATE public.reports
    SET 
        status = p_status,
        reviewed_by = p_moderator_id
    WHERE id = p_report_id;

    -- 3. Log in System Audit Log
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        target_type,
        target_id,
        changes
    ) VALUES (
        p_moderator_id,
        'report_' || p_status::TEXT,
        'report',
        p_report_id,
        jsonb_build_object(
            'target_type', v_target_type,
            'target_id', v_target_id,
            'status', p_status,
            'action_taken', p_action_taken
        )
    );

    RETURN jsonb_build_object('success', true);
END;
$$;


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND user_type = 'admin'
  );
$$;


--
-- Name: is_moderator(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_moderator() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND user_type IN ('admin','moderator')
  );
$$;


--
-- Name: mock_face_verification_processor(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mock_face_verification_processor() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Simulate a delay or check user attributes for mock results
  -- If user name contains 'FailTest' or 'حساب وهمي' or 'مرفوض', simulate rejection
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE id = NEW.user_id 
      AND (
        full_name LIKE '%FailTest%' 
        OR full_name LIKE '%حساب وهمي%' 
        OR full_name LIKE '%مرفوض%'
      )
  ) THEN
    -- Simulate rejection path
    UPDATE public.user_verifications
    SET status = 'rejected',
        rejection_reason = 'عذراً، لم تتطابق ملامح الوجه في صورتك الشخصية السيلفي مع صورة بطاقة الرقم القومي المرفوعة.'
    WHERE id = NEW.id;
    
    UPDATE public.users
    SET is_id_verified = false,
        status = 'active'
    WHERE id = NEW.user_id;

  ELSE
    -- Simulate successful match & approval path
    UPDATE public.user_verifications
    SET status = 'approved',
        verified_at = NOW()
    WHERE id = NEW.id;
    
    UPDATE public.users
    SET is_id_verified = true,
        status = 'active',
        trust_score = GREATEST(trust_score, 4.50) -- Boost trust score to 4.50 stars on successful KYC
    WHERE id = NEW.user_id;

  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: moderate_ad(uuid, uuid, public.mod_action_enum, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.moderate_ad(p_ad_id uuid, p_moderator_id uuid, p_action public.mod_action_enum, p_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_old_status ad_status_enum;
    v_new_status ad_status_enum;
    v_ad_title TEXT;
BEGIN
    -- 1. Fetch current ad details
    SELECT status, title INTO v_old_status, v_ad_title
    FROM public.ads
    WHERE id = p_ad_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'الإعلان غير موجود');
    END IF;

    -- 2. Map moderation action to ad status
    IF p_action = 'approved' THEN
        v_new_status := 'active';
    ELSIF p_action = 'rejected' THEN
        v_new_status := 'rejected';
    ELSE
        -- For other actions like 'flagged', we might not change the status immediately
        v_new_status := v_old_status;
    END IF;

    -- 3. Update the Ad
    UPDATE public.ads
    SET 
        status = v_new_status,
        rejection_reason = CASE WHEN p_action = 'rejected' THEN p_reason ELSE NULL END,
        updated_at = NOW()
    WHERE id = p_ad_id;

    -- 4. Log in Ad Moderation Log
    INSERT INTO public.ad_moderation_log (
        ad_id,
        moderator_id,
        action,
        reason,
        previous_status,
        new_status
    ) VALUES (
        p_ad_id,
        p_moderator_id,
        p_action,
        p_reason,
        v_old_status::VARCHAR,
        v_new_status::VARCHAR
    );

    -- 5. Log in System Audit Log
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        target_type,
        target_id,
        changes
    ) VALUES (
        p_moderator_id,
        'moderate_ad_' || p_action::TEXT,
        'ad',
        p_ad_id,
        jsonb_build_object(
            'title', v_ad_title,
            'old_status', v_old_status,
            'new_status', v_new_status,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', true);
END;
$$;


--
-- Name: moderate_kyc(uuid, uuid, public.verification_status_enum, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.moderate_kyc(p_verification_id uuid, p_moderator_id uuid, p_action public.verification_status_enum, p_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_user_name TEXT;
BEGIN
    -- 1. Fetch verification details
    SELECT user_id INTO v_user_id
    FROM public.user_verifications
    WHERE id = p_verification_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'طلب التوثيق غير موجود');
    END IF;

    SELECT full_name INTO v_user_name FROM public.users WHERE id = v_user_id;

    -- 2. Update the Verification Record
    UPDATE public.user_verifications
    SET 
        status = p_action,
        verified_at = CASE WHEN p_action = 'approved' THEN NOW() ELSE NULL END
    WHERE id = p_verification_id;

    -- 3. Update the User Status
    IF p_action = 'approved' THEN
        UPDATE public.users
        SET 
            status = 'active', -- Ensure user is active if they were pending_verification
            trust_score = GREATEST(trust_score, 80), -- Boost trust score on ID verification
            updated_at = NOW()
        WHERE id = v_user_id;
    END IF;

    -- 4. Log in System Audit Log
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        target_type,
        target_id,
        changes
    ) VALUES (
        p_moderator_id,
        'moderate_kyc_' || p_action::TEXT,
        'user_verification',
        p_verification_id,
        jsonb_build_object(
            'user_name', v_user_name,
            'user_id', v_user_id,
            'status', p_action,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', true);
END;
$$;


--
-- Name: protect_ad_sensitive_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_ad_sensitive_fields() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Check if the current user is a regular user (not admin/moderator)
    -- In Supabase, moderators/admins or service_role will have these functions return true
    -- or will bypass triggers if configured.
    IF NOT (public.is_moderator() OR public.is_admin()) THEN
        
        -- Prevent changing the owner
        IF OLD.user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Ownership cannot be changed directly.';
        END IF;

        -- Prevent self-promoting (bypassing payment)
        IF OLD.is_featured IS DISTINCT FROM NEW.is_featured THEN
            RAISE EXCEPTION 'Featured status can only be modified via payment gateway.';
        END IF;

        IF OLD.is_urgent IS DISTINCT FROM NEW.is_urgent THEN
            RAISE EXCEPTION 'Urgent status can only be modified via payment gateway.';
        END IF;

        -- Prevent bypassing moderation
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            -- Users can only change status to 'paused', 'deleted', 'sold' 
            -- but NOT to 'active' or 'pending' if it was rejected
            IF NEW.status NOT IN ('paused', 'deleted', 'sold') THEN
                RAISE EXCEPTION 'Status change restricted. Use official moderation flow.';
            END IF;
        END IF;

        -- Prevent touching AI risk levels or notes (if they exist)
        -- Using a dynamic check to avoid errors if columns aren't there yet
        BEGIN
            IF OLD.ai_risk_level IS DISTINCT FROM NEW.ai_risk_level THEN
                RAISE EXCEPTION 'AI Risk Level is system-managed.';
            END IF;
        EXCEPTION WHEN undefined_column THEN
            -- Column doesn't exist yet, ignore
        END;

        IF OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason THEN
            RAISE EXCEPTION 'Rejection reason can only be modified by moderators.';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: refresh_user_trust_score(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_user_trust_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE public.users 
    SET trust_score = public.calculate_user_trust_score(
        CASE 
            WHEN TG_TABLE_NAME = 'reviews' THEN NEW.reviewed_user_id
            WHEN TG_TABLE_NAME = 'user_verifications' THEN NEW.user_id
            ELSE NEW.user_id
        END
    )
    WHERE id = (CASE 
                    WHEN TG_TABLE_NAME = 'reviews' THEN NEW.reviewed_user_id 
                    ELSE NEW.user_id 
                END);
    RETURN NEW;
END;
$$;


--
-- Name: set_ad_published_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_ad_published_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.status = 'active' AND OLD.status <> 'active' THEN
    NEW.published_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: sync_ad_location_point(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_ad_location_point() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location_point := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: trigger_notify_ad_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_notify_ad_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Trigger on status change to 'active' or 'rejected'
    IF (TG_OP = 'UPDATE' AND OLD.status <> NEW.status AND NEW.status IN ('active', 'rejected')) THEN
        
        -- Call Edge Function
        PERFORM net.http_post(
            url := concat(current_setting('app.settings.supabase_url'), '/functions/v1/notify-ad-status'),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', concat('Bearer ', current_setting('app.settings.service_role_key'))
            ),
            body := jsonb_build_object(
                'ad_id', NEW.id,
                'new_status', NEW.status,
                'rejection_reason', NEW.rejection_reason
            )
        );
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: trigger_notify_watchlist_match(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_notify_watchlist_match() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Only trigger when status changes to 'active' or a new active ad is created
    IF (TG_OP = 'INSERT' AND NEW.status = 'active') OR 
       (TG_OP = 'UPDATE' AND OLD.status <> 'active' AND NEW.status = 'active') THEN
        
        -- Call Edge Function
        PERFORM net.http_post(
            url := concat(current_setting('app.settings.supabase_url'), '/functions/v1/notify-watchlist-match'),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', concat('Bearer ', current_setting('app.settings.service_role_key'))
            ),
            body := jsonb_build_object('ad_id', NEW.id)
        );
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: update_ad_search_vector(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_ad_search_vector() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('simple', COALESCE(NEW.title, '')),       'A') ||
    setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B');
  RETURN NEW;
END;
$$;


--
-- Name: update_contacts_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_contacts_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE public.ads SET contacts_count = contacts_count + 1 WHERE id = NEW.ad_id;
  RETURN NULL;
END;
$$;


--
-- Name: update_conversation_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_conversation_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = NEW.created_at,
      last_message_preview = substring(NEW.content from 1 for 100)
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;


--
-- Name: update_favorites_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_favorites_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.ads SET favorites_count = favorites_count + 1     WHERE id = NEW.ad_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.ads SET favorites_count = GREATEST(favorites_count - 1, 0) WHERE id = OLD.ad_id;
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: update_trust_score(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_trust_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  target_user UUID;
  v_is_verified BOOLEAN;
  v_avg_rating NUMERIC;
  v_review_count INT;
  v_created_at TIMESTAMPTZ;
  v_months_old INT;
  v_score NUMERIC;
BEGIN
  -- If triggered by reviews table:
  IF TG_TABLE_NAME = 'reviews' THEN
    target_user := COALESCE(NEW.reviewed_user_id, OLD.reviewed_user_id);
  -- If triggered by users table:
  ELSIF TG_TABLE_NAME = 'users' THEN
    target_user := NEW.id;
    -- If is_id_verified did not change, skip update to avoid recursion
    IF NEW.is_id_verified IS NOT DISTINCT FROM OLD.is_id_verified AND NEW.trust_score IS NOT DISTINCT FROM OLD.trust_score THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Get user attributes
  SELECT is_id_verified, created_at
  INTO v_is_verified, v_created_at
  FROM public.users
  WHERE id = target_user;
  
  -- Get review stats (average rating and count)
  SELECT COALESCE(AVG(rating)::NUMERIC, 0.00), COUNT(*)::INT
  INTO v_avg_rating, v_review_count
  FROM public.reviews
  WHERE reviewed_user_id = target_user AND status = 'active';
  
  -- Get account age in months (approximated as 30 days)
  v_months_old := LEAST(floor(EXTRACT(epoch FROM (now() - v_created_at)) / 2592000)::INT, 10);

  -- Calculate score:
  -- 1. Verification: 30 if verified, 0 otherwise
  -- 2. Review average: (v_avg_rating / 5.0) * 40.0
  -- 3. Review count: 1 per review, max 20
  -- 4. Account age: 1 per month, max 10
  v_score := 0.00;
  
  IF v_is_verified THEN
    v_score := v_score + 30.00;
  END IF;
  
  v_score := v_score + (v_avg_rating / 5.00) * 40.00;
  v_score := v_score + LEAST(v_review_count, 20);
  v_score := v_score + v_months_old;
  
  -- Update users table or modify NEW in BEFORE trigger
  IF TG_TABLE_NAME = 'users' THEN
    NEW.trust_score := ROUND(v_score::NUMERIC, 2);
    RETURN NEW;
  ELSE
    UPDATE public.users
    SET trust_score = ROUND(v_score::NUMERIC, 2)
    WHERE id = target_user;
    RETURN NULL;
  END IF;
END;
$$;


--
-- Name: validate_review_eligibility(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_review_eligibility() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: ad_boosts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_boosts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    user_id uuid NOT NULL,
    boost_type public.boost_type_enum NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ad_edit_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_edit_history (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    ad_id uuid,
    old_title character varying(255),
    old_description text,
    old_price numeric(12,2),
    changed_at timestamp with time zone DEFAULT now()
);


--
-- Name: ad_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_fields (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    field_id integer NOT NULL,
    value_text text,
    value_number numeric(15,4),
    value_boolean boolean,
    value_json jsonb
);


--
-- Name: ad_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_media (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    url text NOT NULL,
    thumbnail_url text,
    type public.media_type_enum DEFAULT 'image'::public.media_type_enum NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    size_bytes integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    blurhash text,
    CONSTRAINT ad_media_size_bytes_check CHECK ((size_bytes > 0))
);


--
-- Name: ad_moderation_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_moderation_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    moderator_id uuid NOT NULL,
    action public.mod_action_enum NOT NULL,
    reason text,
    previous_status character varying(30) NOT NULL,
    new_status character varying(30) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ad_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_views (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    viewer_id uuid,
    ip_address inet,
    device_type character varying(20),
    source character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: app_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_configs (
    key character varying(80) NOT NULL,
    value jsonb NOT NULL,
    description text,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: app_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_versions (
    id integer NOT NULL,
    platform character varying(20) NOT NULL,
    min_version character varying(20) NOT NULL,
    latest_version character varying(20) NOT NULL,
    force_update boolean DEFAULT false,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: app_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_versions_id_seq OWNED BY public.app_versions.id;


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action character varying(100) NOT NULL,
    user_id uuid NOT NULL,
    details text,
    performed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid NOT NULL,
    action character varying(80) NOT NULL,
    target_type character varying(30) NOT NULL,
    target_id uuid,
    changes jsonb,
    ip_address inet,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: business_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.business_profiles (
    user_id uuid NOT NULL,
    company_name character varying(150) NOT NULL,
    commercial_registry character varying(50),
    tax_card character varying(50),
    business_address text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id smallint NOT NULL,
    parent_id smallint,
    name_ar character varying(80) NOT NULL,
    name_en character varying(80) NOT NULL,
    slug character varying(80) NOT NULL,
    icon character varying(50),
    level smallint DEFAULT 1 NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT categories_level_check CHECK (((level >= 1) AND (level <= 3)))
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: category_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_fields (
    id integer NOT NULL,
    category_id smallint NOT NULL,
    field_name character varying(50) NOT NULL,
    label_ar character varying(80) NOT NULL,
    label_en character varying(80),
    field_type public.field_type_enum NOT NULL,
    options jsonb,
    is_required boolean DEFAULT false NOT NULL,
    is_searchable boolean DEFAULT false NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL
);


--
-- Name: category_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_fields_id_seq OWNED BY public.category_fields.id;


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cities (
    id integer NOT NULL,
    governorate_id smallint NOT NULL,
    name_ar character varying(80) NOT NULL,
    name_en character varying(80) NOT NULL,
    latitude numeric(10,8),
    longitude numeric(11,8),
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;


--
-- Name: contact_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    user_id uuid,
    contact_type public.contact_type_enum NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    buyer_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_message_at timestamp with time zone DEFAULT now(),
    last_message_preview text
);


--
-- Name: credit_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    type public.credit_tx_type_enum NOT NULL,
    description character varying(200) NOT NULL,
    balance_after numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT credit_transactions_balance_after_check CHECK ((balance_after >= (0)::numeric))
);


--
-- Name: districts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.districts (
    id integer NOT NULL,
    city_id integer NOT NULL,
    name_ar character varying(80) NOT NULL,
    name_en character varying(80)
);


--
-- Name: districts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.districts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: districts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.districts_id_seq OWNED BY public.districts.id;


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    ad_id uuid NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: governorates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.governorates (
    id smallint NOT NULL,
    name_ar character varying(50) NOT NULL,
    name_en character varying(50) NOT NULL,
    code character varying(5) NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: governorates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.governorates_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: governorates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.governorates_id_seq OWNED BY public.governorates.id;


--
-- Name: legal_acceptances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_acceptances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    policy_version character varying(20) NOT NULL,
    accepted_at timestamp with time zone DEFAULT now() NOT NULL,
    ip_address text
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    content text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type public.notification_type_enum NOT NULL,
    title character varying(150) NOT NULL,
    body text NOT NULL,
    data jsonb,
    is_read boolean DEFAULT false NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: otp_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone_number character varying(20) NOT NULL,
    ip_address text DEFAULT 'unknown'::text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    category character varying(50) NOT NULL
);


--
-- Name: push_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    platform public.push_platform_enum NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    target_type public.target_type_enum NOT NULL,
    target_id uuid NOT NULL,
    reason public.report_reason_enum NOT NULL,
    description text,
    status public.report_status_enum DEFAULT 'pending'::public.report_status_enum NOT NULL,
    reviewed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: review_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_responses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    review_id uuid NOT NULL,
    user_id uuid NOT NULL,
    response text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reviewer_id uuid NOT NULL,
    reviewed_user_id uuid NOT NULL,
    ad_id uuid,
    rating smallint NOT NULL,
    comment text,
    status public.review_status_enum DEFAULT 'active'::public.review_status_enum NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT no_self_review CHECK ((reviewer_id <> reviewed_user_id)),
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_searches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name character varying(100),
    category_id smallint,
    city_id integer,
    keywords character varying(200),
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    notify_via public.notify_via_enum DEFAULT 'push'::public.notify_via_enum NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_notified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: service_bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    worker_id uuid NOT NULL,
    scheduled_at timestamp with time zone NOT NULL,
    status public.booking_status_enum DEFAULT 'pending'::public.booking_status_enum NOT NULL,
    customer_notes text,
    agreed_price numeric(10,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT service_bookings_agreed_price_check CHECK ((agreed_price >= (0)::numeric))
);


--
-- Name: subscription_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_plans (
    id smallint NOT NULL,
    name character varying(50) NOT NULL,
    name_ar character varying(50) NOT NULL,
    price_monthly numeric(8,2) DEFAULT 0 NOT NULL,
    price_yearly numeric(8,2) DEFAULT 0 NOT NULL,
    max_ads integer DEFAULT 5 NOT NULL,
    max_images_per_ad smallint DEFAULT 4 NOT NULL,
    features jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    CONSTRAINT subscription_plans_price_monthly_check CHECK ((price_monthly >= (0)::numeric)),
    CONSTRAINT subscription_plans_price_yearly_check CHECK ((price_yearly >= (0)::numeric))
);


--
-- Name: subscription_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscription_plans_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscription_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscription_plans_id_seq OWNED BY public.subscription_plans.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type public.transaction_type_enum NOT NULL,
    reference_id uuid,
    reference_type character varying(30),
    amount numeric(10,2) NOT NULL,
    currency character varying(3) DEFAULT 'EGP'::character varying NOT NULL,
    payment_method public.payment_method_enum NOT NULL,
    payment_gateway character varying(30) NOT NULL,
    gateway_transaction_id character varying(100),
    status public.transaction_status_enum DEFAULT 'pending'::public.transaction_status_enum NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT transactions_amount_check CHECK ((amount > (0)::numeric))
);


--
-- Name: user_activity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_activity_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    action_type public.user_activity_type_enum NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    ip_address inet,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_auth_providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_auth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    provider public.auth_provider_enum NOT NULL,
    provider_user_id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_blocks (
    blocker_id uuid NOT NULL,
    blocked_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_credits (
    user_id uuid NOT NULL,
    balance numeric(10,2) DEFAULT 0.00 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_credits_balance_check CHECK ((balance >= (0)::numeric))
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    granted_by uuid,
    granted_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash character varying(255) NOT NULL,
    device_info jsonb,
    ip_address inet,
    expires_at timestamp with time zone NOT NULL,
    last_used_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    plan_id smallint NOT NULL,
    status public.subscription_status_enum DEFAULT 'active'::public.subscription_status_enum NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    auto_renew boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_verifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type public.verification_type_enum NOT NULL,
    code_hash character varying(255),
    document_url text,
    document_back_url text,
    selfie_url text,
    status public.verification_status_enum DEFAULT 'pending'::public.verification_status_enum NOT NULL,
    attempts smallint DEFAULT 0 NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    national_id character varying(14),
    CONSTRAINT user_verifications_attempts_check CHECK ((attempts >= 0))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying(255),
    phone character varying(20),
    full_name character varying(100) DEFAULT ''::character varying NOT NULL,
    avatar_url text,
    bio text,
    user_type public.user_type_enum DEFAULT 'regular'::public.user_type_enum NOT NULL,
    status public.user_status_enum DEFAULT 'pending_verification'::public.user_status_enum NOT NULL,
    is_phone_verified boolean DEFAULT false NOT NULL,
    is_email_verified boolean DEFAULT false NOT NULL,
    is_id_verified boolean DEFAULT false NOT NULL,
    trust_score numeric(5,2) DEFAULT 0.00 NOT NULL,
    city_id integer,
    last_active_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    notification_preferences jsonb DEFAULT '{"special_offers": true, "ad_status_updates": true, "watchlist_matches": true}'::jsonb,
    CONSTRAINT users_trust_score_check CHECK (((trust_score >= 0.00) AND (trust_score <= 100.00)))
);


--
-- Name: watchlist_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watchlist_notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    ad_id uuid NOT NULL,
    sent_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: app_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_versions ALTER COLUMN id SET DEFAULT nextval('public.app_versions_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_fields ALTER COLUMN id SET DEFAULT nextval('public.category_fields_id_seq'::regclass);


--
-- Name: cities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities ALTER COLUMN id SET DEFAULT nextval('public.cities_id_seq'::regclass);


--
-- Name: districts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.districts ALTER COLUMN id SET DEFAULT nextval('public.districts_id_seq'::regclass);


--
-- Name: governorates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.governorates ALTER COLUMN id SET DEFAULT nextval('public.governorates_id_seq'::regclass);


--
-- Name: subscription_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans ALTER COLUMN id SET DEFAULT nextval('public.subscription_plans_id_seq'::regclass);


--
-- Name: ad_boosts ad_boosts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_boosts
    ADD CONSTRAINT ad_boosts_pkey PRIMARY KEY (id);


--
-- Name: ad_edit_history ad_edit_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_edit_history
    ADD CONSTRAINT ad_edit_history_pkey PRIMARY KEY (id);


--
-- Name: ad_fields ad_fields_ad_id_field_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_fields
    ADD CONSTRAINT ad_fields_ad_id_field_id_key UNIQUE (ad_id, field_id);


--
-- Name: ad_fields ad_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_fields
    ADD CONSTRAINT ad_fields_pkey PRIMARY KEY (id);


--
-- Name: ad_media ad_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_media
    ADD CONSTRAINT ad_media_pkey PRIMARY KEY (id);


--
-- Name: ad_moderation_log ad_moderation_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_moderation_log
    ADD CONSTRAINT ad_moderation_log_pkey PRIMARY KEY (id);


--
-- Name: ad_views ad_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_views
    ADD CONSTRAINT ad_views_pkey PRIMARY KEY (id);


--
-- Name: ads ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_pkey PRIMARY KEY (id);


--
-- Name: ads ads_temp_draft_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_temp_draft_id_key UNIQUE (temp_draft_id);


--
-- Name: app_configs app_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_configs
    ADD CONSTRAINT app_configs_pkey PRIMARY KEY (key);


--
-- Name: app_versions app_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_versions
    ADD CONSTRAINT app_versions_pkey PRIMARY KEY (id);


--
-- Name: app_versions app_versions_platform_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_versions
    ADD CONSTRAINT app_versions_platform_key UNIQUE (platform);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: business_profiles business_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_profiles
    ADD CONSTRAINT business_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);


--
-- Name: category_fields category_fields_category_id_field_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_fields
    ADD CONSTRAINT category_fields_category_id_field_name_key UNIQUE (category_id, field_name);


--
-- Name: category_fields category_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_fields
    ADD CONSTRAINT category_fields_pkey PRIMARY KEY (id);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: contact_logs contact_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_logs
    ADD CONSTRAINT contact_logs_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_ad_id_buyer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_ad_id_buyer_id_key UNIQUE (ad_id, buyer_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: credit_transactions credit_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_pkey PRIMARY KEY (id);


--
-- Name: districts districts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.districts
    ADD CONSTRAINT districts_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_user_id_ad_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_user_id_ad_id_key UNIQUE (user_id, ad_id);


--
-- Name: governorates governorates_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.governorates
    ADD CONSTRAINT governorates_code_key UNIQUE (code);


--
-- Name: governorates governorates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.governorates
    ADD CONSTRAINT governorates_pkey PRIMARY KEY (id);


--
-- Name: legal_acceptances legal_acceptances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_pkey PRIMARY KEY (id);


--
-- Name: legal_acceptances legal_acceptances_user_id_policy_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_user_id_policy_version_key UNIQUE (user_id, policy_version);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: otp_requests otp_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_requests
    ADD CONSTRAINT otp_requests_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_name_key UNIQUE (name);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: push_tokens push_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_tokens
    ADD CONSTRAINT push_tokens_pkey PRIMARY KEY (id);


--
-- Name: push_tokens push_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_tokens
    ADD CONSTRAINT push_tokens_token_key UNIQUE (token);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: review_responses review_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_pkey PRIMARY KEY (id);


--
-- Name: review_responses review_responses_review_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_review_id_key UNIQUE (review_id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_reviewer_id_reviewed_user_id_ad_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_reviewer_id_reviewed_user_id_ad_id_key UNIQUE (reviewer_id, reviewed_user_id, ad_id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: saved_searches saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: service_bookings service_bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_bookings
    ADD CONSTRAINT service_bookings_pkey PRIMARY KEY (id);


--
-- Name: subscription_plans subscription_plans_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_name_key UNIQUE (name);


--
-- Name: subscription_plans subscription_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: user_activity_log user_activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activity_log
    ADD CONSTRAINT user_activity_log_pkey PRIMARY KEY (id);


--
-- Name: user_auth_providers user_auth_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_providers
    ADD CONSTRAINT user_auth_providers_pkey PRIMARY KEY (id);


--
-- Name: user_auth_providers user_auth_providers_provider_provider_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_providers
    ADD CONSTRAINT user_auth_providers_provider_provider_user_id_key UNIQUE (provider, provider_user_id);


--
-- Name: user_blocks user_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (blocker_id, blocked_id);


--
-- Name: user_credits user_credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_credits
    ADD CONSTRAINT user_credits_pkey PRIMARY KEY (user_id);


--
-- Name: user_credits user_credits_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_credits
    ADD CONSTRAINT user_credits_user_id_key UNIQUE (user_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_token_hash_key UNIQUE (token_hash);


--
-- Name: user_subscriptions user_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: user_verifications user_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_verifications
    ADD CONSTRAINT user_verifications_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: watchlist_notifications watchlist_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlist_notifications
    ADD CONSTRAINT watchlist_notifications_pkey PRIMARY KEY (id);


--
-- Name: watchlist_notifications watchlist_notifications_user_id_ad_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlist_notifications
    ADD CONSTRAINT watchlist_notifications_user_id_ad_id_key UNIQUE (user_id, ad_id);


--
-- Name: idx_ad_boosts_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_boosts_active ON public.ad_boosts USING btree (expires_at);


--
-- Name: idx_ad_boosts_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_boosts_ad ON public.ad_boosts USING btree (ad_id, expires_at);


--
-- Name: idx_ad_fields_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_fields_ad ON public.ad_fields USING btree (ad_id);


--
-- Name: idx_ad_media_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_media_ad ON public.ad_media USING btree (ad_id);


--
-- Name: idx_ad_media_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_media_primary ON public.ad_media USING btree (ad_id, is_primary) WHERE (is_primary = true);


--
-- Name: idx_ad_views_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_views_ad ON public.ad_views USING btree (ad_id, created_at DESC);


--
-- Name: idx_ad_views_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_views_user ON public.ad_views USING btree (viewer_id) WHERE (viewer_id IS NOT NULL);


--
-- Name: idx_ads_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_category ON public.ads USING btree (category_id);


--
-- Name: idx_ads_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_city ON public.ads USING btree (city_id);


--
-- Name: idx_ads_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_created ON public.ads USING btree (created_at DESC);


--
-- Name: idx_ads_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_expires ON public.ads USING btree (expires_at) WHERE (status = 'active'::public.ad_status_enum);


--
-- Name: idx_ads_featured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_featured ON public.ads USING btree (is_featured) WHERE (is_featured = true);


--
-- Name: idx_ads_is_hidden; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_is_hidden ON public.ads USING btree (is_hidden) WHERE (is_hidden = true);


--
-- Name: idx_ads_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_location ON public.ads USING btree (latitude, longitude) WHERE (latitude IS NOT NULL);


--
-- Name: idx_ads_location_point; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_location_point ON public.ads USING gist (location_point);


--
-- Name: idx_ads_price; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_price ON public.ads USING btree (price) WHERE (price IS NOT NULL);


--
-- Name: idx_ads_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_search ON public.ads USING gin (search_vector);


--
-- Name: idx_ads_search_attr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_search_attr ON public.ads USING gin (search_attributes);


--
-- Name: idx_ads_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_search_vector ON public.ads USING gin (search_vector);


--
-- Name: idx_ads_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_status ON public.ads USING btree (status);


--
-- Name: idx_ads_status_city_dt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_status_city_dt ON public.ads USING btree (status, city_id, created_at DESC);


--
-- Name: idx_ads_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_status_created ON public.ads USING btree (status, created_at DESC);


--
-- Name: idx_ads_urgent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_urgent ON public.ads USING btree (is_urgent) WHERE (is_urgent = true);


--
-- Name: idx_ads_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_user ON public.ads USING btree (user_id);


--
-- Name: idx_audit_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_actor ON public.audit_logs USING btree (actor_id, created_at DESC);


--
-- Name: idx_audit_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_target ON public.audit_logs USING btree (target_type, target_id);


--
-- Name: idx_bookings_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_customer ON public.service_bookings USING btree (customer_id);


--
-- Name: idx_bookings_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_status ON public.service_bookings USING btree (status);


--
-- Name: idx_bookings_worker; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_worker ON public.service_bookings USING btree (worker_id);


--
-- Name: idx_cat_fields_cat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cat_fields_cat ON public.category_fields USING btree (category_id);


--
-- Name: idx_categories_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_categories_parent ON public.categories USING btree (parent_id) WHERE (parent_id IS NOT NULL);


--
-- Name: idx_categories_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_categories_slug ON public.categories USING btree (slug);


--
-- Name: idx_cities_gov; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cities_gov ON public.cities USING btree (governorate_id);


--
-- Name: idx_contact_logs_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contact_logs_ad ON public.contact_logs USING btree (ad_id);


--
-- Name: idx_contact_logs_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contact_logs_user ON public.contact_logs USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_conversations_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_ad ON public.conversations USING btree (ad_id);


--
-- Name: idx_conversations_buyer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_buyer ON public.conversations USING btree (buyer_id);


--
-- Name: idx_conversations_seller; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_seller ON public.conversations USING btree (seller_id);


--
-- Name: idx_credit_tx_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_credit_tx_user ON public.credit_transactions USING btree (user_id, created_at DESC);


--
-- Name: idx_districts_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_districts_city ON public.districts USING btree (city_id);


--
-- Name: idx_favorites_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_favorites_ad ON public.favorites USING btree (ad_id);


--
-- Name: idx_favorites_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_favorites_user ON public.favorites USING btree (user_id);


--
-- Name: idx_messages_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_conversation ON public.messages USING btree (conversation_id, created_at DESC);


--
-- Name: idx_mod_log_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mod_log_ad ON public.ad_moderation_log USING btree (ad_id);


--
-- Name: idx_notifs_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifs_unread ON public.notifications USING btree (user_id) WHERE (is_read = false);


--
-- Name: idx_notifs_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifs_user ON public.notifications USING btree (user_id, is_read, created_at DESC);


--
-- Name: idx_otp_requests_phone_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_requests_phone_time ON public.otp_requests USING btree (phone_number, requested_at DESC);


--
-- Name: idx_push_tokens_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_tokens_active ON public.push_tokens USING btree (user_id) WHERE (is_active = true);


--
-- Name: idx_push_tokens_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_tokens_user ON public.push_tokens USING btree (user_id) WHERE (is_active = true);


--
-- Name: idx_reports_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_status ON public.reports USING btree (status) WHERE (status = 'pending'::public.report_status_enum);


--
-- Name: idx_reviews_reviewed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_reviewed ON public.reviews USING btree (reviewed_user_id);


--
-- Name: idx_reviews_reviewer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_reviewer ON public.reviews USING btree (reviewer_id);


--
-- Name: idx_saved_searches_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_saved_searches_user ON public.saved_searches USING btree (user_id) WHERE (is_active = true);


--
-- Name: idx_sessions_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessions_expires ON public.user_sessions USING btree (expires_at);


--
-- Name: idx_sessions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessions_user ON public.user_sessions USING btree (user_id);


--
-- Name: idx_subs_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subs_user ON public.user_subscriptions USING btree (user_id, status);


--
-- Name: idx_transactions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transactions_status ON public.transactions USING btree (status);


--
-- Name: idx_transactions_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transactions_status_created ON public.transactions USING btree (status, created_at DESC);


--
-- Name: idx_transactions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transactions_user ON public.transactions USING btree (user_id, created_at DESC);


--
-- Name: idx_user_activity_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activity_user_id ON public.user_activity_log USING btree (user_id, created_at DESC);


--
-- Name: idx_users_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_city ON public.users USING btree (city_id) WHERE (city_id IS NOT NULL);


--
-- Name: idx_users_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_deleted_at ON public.users USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone) WHERE (phone IS NOT NULL);


--
-- Name: idx_users_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_status ON public.users USING btree (status);


--
-- Name: idx_users_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_type ON public.users USING btree (user_type);


--
-- Name: idx_watchlist_user_cat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_watchlist_user_cat ON public.saved_searches USING btree (category_id, is_active) WHERE (is_active = true);


--
-- Name: reviews tr_refresh_trust_on_review; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_refresh_trust_on_review AFTER INSERT OR UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.refresh_user_trust_score();


--
-- Name: ads tr_sync_ad_location; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_sync_ad_location BEFORE INSERT OR UPDATE OF latitude, longitude ON public.ads FOR EACH ROW EXECUTE FUNCTION public.sync_ad_location_point();


--
-- Name: messages tr_update_conversation_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_conversation_timestamp AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_conversation_timestamp();


--
-- Name: ads trg_ads_published_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ads_published_at BEFORE UPDATE OF status ON public.ads FOR EACH ROW EXECUTE FUNCTION public.set_ad_published_at();


--
-- Name: ads trg_ads_search_vector; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ads_search_vector BEFORE INSERT OR UPDATE OF title, description ON public.ads FOR EACH ROW EXECUTE FUNCTION public.update_ad_search_vector();


--
-- Name: ads trg_ads_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ads_updated_at BEFORE UPDATE ON public.ads FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: service_bookings trg_bookings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_bookings_updated_at BEFORE UPDATE ON public.service_bookings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contact_logs trg_contacts_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_contacts_count AFTER INSERT ON public.contact_logs FOR EACH ROW EXECUTE FUNCTION public.update_contacts_count();


--
-- Name: favorites trg_favorites_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_favorites_count AFTER INSERT OR DELETE ON public.favorites FOR EACH ROW EXECUTE FUNCTION public.update_favorites_count();


--
-- Name: user_verifications trg_mock_face_verification; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mock_face_verification AFTER INSERT ON public.user_verifications FOR EACH ROW EXECUTE FUNCTION public.mock_face_verification_processor();


--
-- Name: ads trg_notify_ad_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_ad_status AFTER UPDATE OF status ON public.ads FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_ad_status();


--
-- Name: ads trg_notify_watchlist; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_watchlist AFTER INSERT OR UPDATE OF status ON public.ads FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_watchlist_match();


--
-- Name: ads trg_protect_ad_fields; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_ad_fields BEFORE UPDATE ON public.ads FOR EACH ROW EXECUTE FUNCTION public.protect_ad_sensitive_fields();


--
-- Name: reviews trg_trust_score; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_trust_score AFTER INSERT OR DELETE OR UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_trust_score();


--
-- Name: users trg_trust_score_users; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_trust_score_users BEFORE UPDATE OF is_id_verified ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_trust_score();


--
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: reviews trg_validate_review; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_review BEFORE INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.validate_review_eligibility();


--
-- Name: ad_boosts ad_boosts_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_boosts
    ADD CONSTRAINT ad_boosts_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: ad_boosts ad_boosts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_boosts
    ADD CONSTRAINT ad_boosts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ad_edit_history ad_edit_history_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_edit_history
    ADD CONSTRAINT ad_edit_history_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: ad_fields ad_fields_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_fields
    ADD CONSTRAINT ad_fields_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: ad_fields ad_fields_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_fields
    ADD CONSTRAINT ad_fields_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.category_fields(id) ON DELETE CASCADE;


--
-- Name: ad_media ad_media_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_media
    ADD CONSTRAINT ad_media_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: ad_moderation_log ad_moderation_log_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_moderation_log
    ADD CONSTRAINT ad_moderation_log_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: ad_moderation_log ad_moderation_log_moderator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_moderation_log
    ADD CONSTRAINT ad_moderation_log_moderator_id_fkey FOREIGN KEY (moderator_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ad_views ad_views_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_views
    ADD CONSTRAINT ad_views_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: ad_views ad_views_viewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_views
    ADD CONSTRAINT ad_views_viewer_id_fkey FOREIGN KEY (viewer_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ads ads_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: ads ads_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE RESTRICT;


--
-- Name: ads ads_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.districts(id) ON DELETE SET NULL;


--
-- Name: ads ads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: app_configs app_configs_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_configs
    ADD CONSTRAINT app_configs_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: audit_log audit_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: audit_logs audit_logs_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: business_profiles business_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_profiles
    ADD CONSTRAINT business_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: category_fields category_fields_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_fields
    ADD CONSTRAINT category_fields_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: cities cities_governorate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_governorate_id_fkey FOREIGN KEY (governorate_id) REFERENCES public.governorates(id) ON DELETE RESTRICT;


--
-- Name: contact_logs contact_logs_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_logs
    ADD CONSTRAINT contact_logs_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: contact_logs contact_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_logs
    ADD CONSTRAINT contact_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: conversations conversations_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_buyer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_seller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: credit_transactions credit_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: districts districts_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.districts
    ADD CONSTRAINT districts_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE RESTRICT;


--
-- Name: favorites favorites_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: favorites favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: legal_acceptances legal_acceptances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_acceptances
    ADD CONSTRAINT legal_acceptances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: push_tokens push_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_tokens
    ADD CONSTRAINT push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: review_responses review_responses_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE CASCADE;


--
-- Name: review_responses review_responses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE SET NULL;


--
-- Name: reviews reviews_reviewed_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_reviewed_user_id_fkey FOREIGN KEY (reviewed_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: saved_searches saved_searches_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: saved_searches saved_searches_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE SET NULL;


--
-- Name: saved_searches saved_searches_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: service_bookings service_bookings_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_bookings
    ADD CONSTRAINT service_bookings_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE RESTRICT;


--
-- Name: service_bookings service_bookings_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_bookings
    ADD CONSTRAINT service_bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: service_bookings service_bookings_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_bookings
    ADD CONSTRAINT service_bookings_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: transactions transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_activity_log user_activity_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activity_log
    ADD CONSTRAINT user_activity_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_auth_providers user_auth_providers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_providers
    ADD CONSTRAINT user_auth_providers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocked_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_credits user_credits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_credits
    ADD CONSTRAINT user_credits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_granted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_subscriptions user_subscriptions_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id) ON DELETE RESTRICT;


--
-- Name: user_subscriptions user_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_verifications user_verifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_verifications
    ADD CONSTRAINT user_verifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE SET NULL;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: watchlist_notifications watchlist_notifications_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlist_notifications
    ADD CONSTRAINT watchlist_notifications_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;


--
-- Name: watchlist_notifications watchlist_notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlist_notifications
    ADD CONSTRAINT watchlist_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: audit_log Admins/Moderators can view audit logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins/Moderators can view audit logs" ON public.audit_log FOR SELECT TO authenticated USING ((( SELECT users.user_type
   FROM public.users
  WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::public.user_type_enum, 'moderator'::public.user_type_enum])));


--
-- Name: audit_log System can insert audit logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "System can insert audit logs" ON public.audit_log FOR INSERT TO authenticated, service_role WITH CHECK (true);


--
-- Name: ad_boosts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_boosts ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_edit_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_edit_history ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_edit_history ad_edit_history_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_edit_history_select ON public.ad_edit_history FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.ads
  WHERE ((ads.id = ad_edit_history.ad_id) AND (ads.user_id = auth.uid())))));


--
-- Name: ad_fields; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_fields ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_fields ad_fields_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_fields_insert ON public.ad_fields FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.ads
  WHERE ((ads.id = ad_fields.ad_id) AND (ads.user_id = auth.uid())))));


--
-- Name: ad_fields ad_fields_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_fields_select ON public.ad_fields FOR SELECT USING (true);


--
-- Name: ad_media; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_media ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_media ad_media_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_media_delete ON public.ad_media FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.ads
  WHERE ((ads.id = ad_media.ad_id) AND (ads.user_id = auth.uid())))));


--
-- Name: ad_media ad_media_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_media_insert ON public.ad_media FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.ads
  WHERE ((ads.id = ad_media.ad_id) AND (ads.user_id = auth.uid())))));


--
-- Name: ad_media ad_media_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_media_select ON public.ad_media FOR SELECT USING (true);


--
-- Name: ad_moderation_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_moderation_log ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_views; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_views ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_views ad_views_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_views_insert ON public.ad_views FOR INSERT WITH CHECK (true);


--
-- Name: ad_views ad_views_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_views_select ON public.ad_views FOR SELECT USING (((viewer_id = auth.uid()) OR public.is_admin()));


--
-- Name: user_activity_log admin_all_access_activity; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_access_activity ON public.user_activity_log USING ((public.is_admin() OR public.is_moderator()));


--
-- Name: ads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

--
-- Name: ads ads_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ads_delete ON public.ads FOR DELETE USING (((user_id = auth.uid()) OR public.is_admin()));


--
-- Name: ads ads_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ads_insert ON public.ads FOR INSERT WITH CHECK (((auth.uid() IS NOT NULL) AND (user_id = auth.uid())));


--
-- Name: ads ads_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ads_select ON public.ads FOR SELECT USING (((status = 'active'::public.ad_status_enum) OR (user_id = auth.uid()) OR public.is_moderator()));


--
-- Name: ads ads_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ads_update ON public.ads FOR UPDATE USING (((user_id = auth.uid()) OR public.is_moderator()));


--
-- Name: app_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: app_versions app_versions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_versions_select ON public.app_versions FOR SELECT USING (true);


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: user_auth_providers auth_providers_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_providers_own ON public.user_auth_providers USING ((user_id = auth.uid()));


--
-- Name: user_blocks blocks_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_delete ON public.user_blocks FOR DELETE USING ((blocker_id = auth.uid()));


--
-- Name: user_blocks blocks_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_insert ON public.user_blocks FOR INSERT WITH CHECK ((blocker_id = auth.uid()));


--
-- Name: user_blocks blocks_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_select ON public.user_blocks FOR SELECT USING ((blocker_id = auth.uid()));


--
-- Name: service_bookings bookings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_insert ON public.service_bookings FOR INSERT WITH CHECK ((customer_id = auth.uid()));


--
-- Name: service_bookings bookings_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_select ON public.service_bookings FOR SELECT USING (((customer_id = auth.uid()) OR (worker_id = auth.uid()) OR public.is_moderator()));


--
-- Name: service_bookings bookings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_update ON public.service_bookings FOR UPDATE USING (((customer_id = auth.uid()) OR (worker_id = auth.uid()) OR public.is_moderator()));


--
-- Name: ad_boosts boosts_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY boosts_select ON public.ad_boosts FOR SELECT USING (true);


--
-- Name: business_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.business_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: business_profiles business_profiles_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY business_profiles_insert ON public.business_profiles FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: business_profiles business_profiles_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY business_profiles_select ON public.business_profiles FOR SELECT USING (true);


--
-- Name: business_profiles business_profiles_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY business_profiles_update ON public.business_profiles FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: contact_logs contact_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contact_insert ON public.contact_logs FOR INSERT WITH CHECK (true);


--
-- Name: contact_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contact_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: contact_logs contact_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contact_select ON public.contact_logs FOR SELECT USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.ads
  WHERE ((ads.id = contact_logs.ad_id) AND (ads.user_id = auth.uid())))) OR public.is_admin()));


--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations conversations_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversations_insert ON public.conversations FOR INSERT WITH CHECK ((buyer_id = auth.uid()));


--
-- Name: conversations conversations_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversations_select ON public.conversations FOR SELECT USING (((buyer_id = auth.uid()) OR (seller_id = auth.uid()) OR public.is_admin()));


--
-- Name: credit_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: credit_transactions credit_tx_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY credit_tx_own ON public.credit_transactions USING ((user_id = auth.uid()));


--
-- Name: user_credits credits_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY credits_own ON public.user_credits USING ((user_id = auth.uid()));


--
-- Name: favorites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

--
-- Name: favorites favorites_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY favorites_own ON public.favorites USING ((user_id = auth.uid()));


--
-- Name: legal_acceptances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.legal_acceptances ENABLE ROW LEVEL SECURITY;

--
-- Name: legal_acceptances legal_acceptances_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY legal_acceptances_insert_own ON public.legal_acceptances FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: legal_acceptances legal_acceptances_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY legal_acceptances_select_own ON public.legal_acceptances FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: messages messages_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_insert ON public.messages FOR INSERT WITH CHECK (((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND ((conversations.buyer_id = auth.uid()) OR (conversations.seller_id = auth.uid())))))));


--
-- Name: messages messages_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_select ON public.messages FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND ((conversations.buyer_id = auth.uid()) OR (conversations.seller_id = auth.uid()))))));


--
-- Name: ad_moderation_log mod_log_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mod_log_insert ON public.ad_moderation_log FOR INSERT WITH CHECK (public.is_moderator());


--
-- Name: ad_moderation_log mod_log_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mod_log_select ON public.ad_moderation_log FOR SELECT USING ((public.is_moderator() OR (EXISTS ( SELECT 1
   FROM public.ads
  WHERE ((ads.id = ad_moderation_log.ad_id) AND (ads.user_id = auth.uid()))))));


--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifs_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifs_own ON public.notifications USING ((user_id = auth.uid()));


--
-- Name: otp_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: otp_requests otp_requests_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY otp_requests_service_only ON public.otp_requests USING (false) WITH CHECK (false);


--
-- Name: push_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: push_tokens push_tokens_all_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY push_tokens_all_own ON public.push_tokens USING ((user_id = auth.uid()));


--
-- Name: push_tokens push_tokens_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY push_tokens_delete ON public.push_tokens FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: push_tokens push_tokens_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY push_tokens_insert ON public.push_tokens FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: push_tokens push_tokens_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY push_tokens_select ON public.push_tokens FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

--
-- Name: reports reports_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reports_insert ON public.reports FOR INSERT WITH CHECK (((auth.uid() IS NOT NULL) AND (reporter_id = auth.uid())));


--
-- Name: reports reports_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reports_select ON public.reports FOR SELECT USING (((reporter_id = auth.uid()) OR public.is_moderator()));


--
-- Name: reports reports_update_mod; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reports_update_mod ON public.reports FOR UPDATE USING (public.is_moderator());


--
-- Name: review_responses rev_resp_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rev_resp_insert ON public.review_responses FOR INSERT WITH CHECK (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.reviews
  WHERE ((reviews.id = review_responses.review_id) AND (reviews.reviewed_user_id = auth.uid()))))));


--
-- Name: review_responses rev_resp_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rev_resp_select ON public.review_responses FOR SELECT USING (true);


--
-- Name: review_responses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.review_responses ENABLE ROW LEVEL SECURITY;

--
-- Name: reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: reviews reviews_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reviews_insert ON public.reviews FOR INSERT WITH CHECK (((auth.uid() IS NOT NULL) AND (reviewer_id = auth.uid())));


--
-- Name: reviews reviews_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reviews_select ON public.reviews FOR SELECT USING ((status = 'active'::public.review_status_enum));


--
-- Name: reviews reviews_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reviews_update_own ON public.reviews FOR UPDATE USING ((reviewer_id = auth.uid()));


--
-- Name: saved_searches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;

--
-- Name: saved_searches saved_searches_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY saved_searches_own ON public.saved_searches USING ((user_id = auth.uid()));


--
-- Name: service_bookings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.service_bookings ENABLE ROW LEVEL SECURITY;

--
-- Name: user_sessions sessions_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sessions_own ON public.user_sessions USING ((user_id = auth.uid()));


--
-- Name: user_subscriptions subs_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subs_own ON public.user_subscriptions USING ((user_id = auth.uid()));


--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions transactions_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY transactions_select_own ON public.transactions FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: user_activity_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_activity_log ENABLE ROW LEVEL SECURITY;

--
-- Name: user_auth_providers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_auth_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: user_blocks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

--
-- Name: user_blocks user_blocks_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_blocks_delete ON public.user_blocks FOR DELETE USING ((auth.uid() = blocker_id));


--
-- Name: user_blocks user_blocks_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_blocks_insert ON public.user_blocks FOR INSERT WITH CHECK ((auth.uid() = blocker_id));


--
-- Name: user_blocks user_blocks_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_blocks_select ON public.user_blocks FOR SELECT USING ((auth.uid() = blocker_id));


--
-- Name: user_credits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_credits ENABLE ROW LEVEL SECURITY;

--
-- Name: user_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_verifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_verifications ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_delete_own ON public.users FOR DELETE USING ((id = auth.uid()));


--
-- Name: users users_insert_trigger; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_insert_trigger ON public.users FOR INSERT WITH CHECK (true);


--
-- Name: users users_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select_all ON public.users FOR SELECT USING (((deleted_at IS NULL) OR (id = auth.uid())));


--
-- Name: users users_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_update_own ON public.users FOR UPDATE USING ((id = auth.uid()));


--
-- Name: user_verifications verifications_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verifications_insert ON public.user_verifications FOR INSERT TO authenticated WITH CHECK (((user_id = auth.uid()) AND (status = 'pending'::public.verification_status_enum)));


--
-- Name: user_verifications verifications_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verifications_insert_own ON public.user_verifications FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: user_verifications verifications_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verifications_select ON public.user_verifications FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR (( SELECT users.user_type
   FROM public.users
  WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::public.user_type_enum, 'moderator'::public.user_type_enum]))));


--
-- Name: user_verifications verifications_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verifications_select_own ON public.user_verifications FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: user_verifications verifications_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verifications_update ON public.user_verifications FOR UPDATE TO authenticated USING ((( SELECT users.user_type
   FROM public.users
  WHERE (users.id = auth.uid())) = ANY (ARRAY['admin'::public.user_type_enum, 'moderator'::public.user_type_enum])));


--
-- PostgreSQL database dump complete
--

-- ── Reference data ──────────────────────────────────────────────
--
-- PostgreSQL database dump
--


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: app_configs; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('max_free_ads', '5', 'الحد الأقصى للإعلانات المجانية النشطة', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('ad_expiry_days', '30', 'أيام صلاحية الإعلان', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('otp_expiry_minutes', '10', 'مدة صلاحية الـ OTP بالدقائق', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('otp_max_attempts', '5', 'الحد الأقصى لمحاولات OTP', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('boost_featured_3d', '30', 'سعر Featured 3 أيام بالجنيه', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('boost_featured_7d', '60', 'سعر Featured 7 أيام', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('boost_featured_14d', '100', 'سعر Featured 14 يوم', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('boost_featured_30d', '180', 'سعر Featured 30 يوم', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('boost_urgent_7d', '40', 'سعر Urgent Badge 7 أيام', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('boost_bump', '10', 'سعر Bump مرة واحدة', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('max_watchlist_per_user', '10', 'الحد الأقصى للبحوث المحفوظة', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('max_ad_title_chars', '120', 'الحد الأقصى لأحرف عنوان الإعلان', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('platform_currency', '"EGP"', 'عملة المنصة', NULL, '2026-10-26 13:13:04.300193+00');
INSERT INTO public.app_configs (key, value, description, updated_by, updated_at) VALUES ('maintenance_mode', 'false', 'وضع الصيانة', NULL, '2026-10-26 13:13:04.300193+00');


--
-- Data for Name: app_versions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.app_versions (id, platform, min_version, latest_version, force_update, updated_at) VALUES (1, 'android', '1.0.0', '1.0.0', false, '2026-10-26 13:13:06.210835+00');
INSERT INTO public.app_versions (id, platform, min_version, latest_version, force_update, updated_at) VALUES (2, 'ios', '1.0.0', '1.0.0', false, '2026-10-26 13:13:06.210835+00');


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (1, NULL, 'خدمات', 'Services', 'services', '🔧', 1, 1, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (2, NULL, 'وظائف', 'Jobs', 'jobs', '💼', 1, 2, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (3, NULL, 'عقارات', 'Real Estate', 'real-estate', '🏠', 1, 3, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (4, NULL, 'سيارات', 'Vehicles', 'vehicles', '🚗', 1, 4, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (5, NULL, 'سلع', 'Goods', 'goods', '📦', 1, 5, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (6, 1, 'سباكة وصرف صحي', 'Plumbing', 'plumbing', '🚿', 2, 1, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (7, 1, 'كهرباء ومنازل', 'Electrical', 'electrical', '💡', 2, 2, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (8, 1, 'تدريس وتعليم', 'Teaching', 'teaching', '📚', 2, 3, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (9, 1, 'تنظيف ومكافحة', 'Cleaning', 'cleaning', '🧹', 2, 4, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (10, 1, 'نجارة وأثاث', 'Carpentry', 'carpentry', '🪚', 2, 5, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (11, 1, 'دهانات وديكور', 'Painting', 'painting', '🎨', 2, 6, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (12, 1, 'تكييف وتبريد', 'AC & Cooling', 'ac-cooling', '❄️', 2, 7, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (13, 1, 'مواصلات وتوصيل', 'Transport', 'transport', '🚚', 2, 8, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (14, 1, 'تصميم وبرمجة', 'Design & Dev', 'design-dev', '💻', 2, 9, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (15, 1, 'صحة وتمريض', 'Healthcare', 'healthcare', '🏥', 2, 10, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (16, 2, 'وظائف إدارية', 'Administrative', 'admin-jobs', '📋', 2, 1, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (17, 2, 'مبيعات وتسويق', 'Sales', 'sales-jobs', '📈', 2, 2, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (18, 2, 'هندسة وتقنية', 'Engineering/IT', 'tech-jobs', '⚙️', 2, 3, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (19, 2, 'صحة وطب', 'Medical', 'medical-jobs', '🩺', 2, 4, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (20, 2, 'تعليم وتدريب', 'Education', 'edu-jobs', '🎓', 2, 5, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (21, 2, 'سياحة وفنادق', 'Tourism', 'tourism-jobs', '🏨', 2, 6, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (22, 2, 'أمن وحراسة', 'Security', 'security-jobs', '🔒', 2, 7, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (23, 3, 'شقق للإيجار', 'Apartments Rent', 'apt-rent', '🏢', 2, 1, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (24, 3, 'شقق للبيع', 'Apartments Sale', 'apt-sale', '🏠', 2, 2, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (25, 3, 'غرف للإيجار', 'Rooms Rent', 'rooms-rent', '🛏️', 2, 3, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (26, 3, 'فيلات ودوبلكس', 'Villas', 'villas', '🏡', 2, 4, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (27, 3, 'محلات تجارية', 'Commercial', 'commercial', '🏪', 2, 5, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (28, 3, 'أراضي', 'Land', 'land', '🌍', 2, 6, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (29, 4, 'سيارات', 'Cars', 'cars', '🚗', 2, 1, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (30, 4, 'دراجات نارية', 'Motorcycles', 'motorcycles', '🏍️', 2, 2, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (31, 4, 'تكاتك', 'Tuk Tuks', 'tuk-tuks', '🛺', 2, 3, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (32, 4, 'شاحنات ونقل', 'Trucks', 'trucks', '🚛', 2, 4, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (33, 5, 'إلكترونيات', 'Electronics', 'electronics', '📱', 2, 1, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (34, 5, 'أثاث وديكور', 'Furniture', 'furniture', '🛋️', 2, 2, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (35, 5, 'ملابس وأكسسوار', 'Fashion', 'fashion', '👗', 2, 3, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (36, 5, 'أجهزة منزلية', 'Appliances', 'appliances', '🏠', 2, 4, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (37, 5, 'رياضة وترفيه', 'Sports', 'sports', '⚽', 2, 5, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (38, 5, 'مستلزمات أطفال', 'Kids', 'kids', '🧸', 2, 6, true);
INSERT INTO public.categories (id, parent_id, name_ar, name_en, slug, icon, level, sort_order, is_active) VALUES (39, 5, 'كتب ومستلزمات', 'Books', 'books', '📖', 2, 7, true);


--
-- Data for Name: category_fields; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (1, 2, 'job_type', 'نوع الوظيفة', NULL, 'select', '["دوام كامل", "دوام جزئي", "فريلانس", "تدريب"]', true, false, 1);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (2, 2, 'experience_required', 'الخبرة المطلوبة', NULL, 'select', '["بدون خبرة", "أقل من سنة", "1-3 سنوات", "3-5 سنوات", "أكثر من 5 سنوات"]', false, false, 2);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (3, 3, 'property_type', 'نوع العقار', NULL, 'select', '["شقة", "فيلا", "دوبلكس", "محل تجاري", "مكتب", "أرض", "أخرى"]', true, false, 1);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (4, 3, 'area_sqm', 'المساحة (متر مربع)', NULL, 'number', NULL, true, false, 2);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (5, 3, 'rooms', 'عدد الغرف', NULL, 'select', '["استوديو", "1", "2", "3", "4", "5+"]', false, false, 3);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (6, 3, 'furnished', 'مفروشة', NULL, 'boolean', NULL, false, false, 4);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (7, 4, 'brand', 'الماركة', NULL, 'select', '["تويوتا", "هيونداي", "كيا", "نيسان", "شيفروليه", "فيات", "بيجو", "رينو", "أخرى"]', true, false, 1);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (8, 4, 'year', 'سنة الصنع', NULL, 'number', NULL, true, false, 2);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (9, 4, 'mileage', 'عداد الكيلومترات', NULL, 'number', NULL, false, false, 3);
INSERT INTO public.category_fields (id, category_id, field_name, label_ar, label_en, field_type, options, is_required, is_searchable, sort_order) VALUES (10, 4, 'condition', 'حالة السيارة', NULL, 'select', '["ممتاز", "جيد جداً", "جيد", "يحتاج صيانة"]', true, false, 4);


--
-- Data for Name: governorates; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (1, 'القاهرة', 'Cairo', 'CAI', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (2, 'الإسكندرية', 'Alexandria', 'ALX', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (3, 'الجيزة', 'Giza', 'GIZ', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (4, 'القليوبية', 'Qalyubia', 'QAL', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (5, 'الشرقية', 'Sharqia', 'SHA', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (6, 'الدقهلية', 'Dakahlia', 'DAK', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (7, 'البحيرة', 'Beheira', 'BEH', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (8, 'المنوفية', 'Menoufia', 'MEN', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (9, 'الغربية', 'Gharbia', 'GHA', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (10, 'كفر الشيخ', 'Kafr el-Sheikh', 'KFS', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (11, 'دمياط', 'Damietta', 'DAM', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (12, 'بورسعيد', 'Port Said', 'POR', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (13, 'الإسماعيلية', 'Ismailia', 'ISM', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (14, 'السويس', 'Suez', 'SUE', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (15, 'شمال سيناء', 'North Sinai', 'NSI', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (16, 'جنوب سيناء', 'South Sinai', 'SSI', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (17, 'البحر الأحمر', 'Red Sea', 'RSE', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (18, 'الوادي الجديد', 'New Valley', 'NVA', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (19, 'مطروح', 'Matruh', 'MAT', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (20, 'أسيوط', 'Asyut', 'ASY', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (21, 'سوهاج', 'Sohag', 'SOH', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (22, 'قنا', 'Qena', 'QEN', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (23, 'الأقصر', 'Luxor', 'LUX', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (24, 'أسوان', 'Aswan', 'ASW', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (25, 'المنيا', 'Minya', 'MIN', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (26, 'بني سويف', 'Beni Suef', 'BNS', true);
INSERT INTO public.governorates (id, name_ar, name_en, code, is_active) VALUES (27, 'الفيوم', 'Faiyum', 'FAI', true);


--
-- Data for Name: cities; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (1, 1, 'وسط القاهرة', 'Downtown Cairo', 30.04440000, 31.23570000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (2, 1, 'مدينة نصر', 'Nasr City', 30.06260000, 31.34220000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (3, 1, 'المعادي', 'Maadi', 29.96020000, 31.25690000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (4, 1, 'مصر الجديدة', 'Heliopolis', 30.08920000, 31.32140000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (5, 1, 'الزمالك', 'Zamalek', 30.06590000, 31.21950000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (6, 1, 'شبرا', 'Shubra', 30.10570000, 31.24230000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (7, 1, 'عين شمس', 'Ain Shams', 30.10650000, 31.32680000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (8, 1, 'حلوان', 'Helwan', 29.84480000, 31.33370000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (9, 1, 'التجمع الخامس', 'Fifth Settlement', 30.00870000, 31.47330000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (10, 1, 'مدينتي', 'Madinaty', 30.11690000, 31.64380000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (11, 1, 'الرحاب', 'Al Rehab', 30.05860000, 31.49260000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (12, 1, 'العباسية', 'Abbasiya', 30.06310000, 31.27860000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (13, 1, 'المطرية', 'Matareya', 30.12210000, 31.30930000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (14, 1, 'حدائق الأهرام', 'Ahram Gardens', 29.98630000, 31.13730000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (15, 1, 'شبرا الخيمة', 'Shubra El Kheima', 30.12910000, 31.24630000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (16, 3, 'الدقي', 'Dokki', 30.04030000, 31.21060000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (17, 3, 'المهندسين', 'Mohandessin', 30.05740000, 31.19930000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (18, 3, 'الهرم', 'Haram', 29.98990000, 31.15970000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (19, 3, '6 أكتوبر', '6th of October', 29.93600000, 31.01170000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (20, 3, 'الشيخ زايد', 'Sheikh Zayed', 30.01310000, 30.94720000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (21, 3, 'فيصل', 'Faisal', 29.99850000, 31.12800000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (22, 3, 'إمبابة', 'Imbaba', 30.07720000, 31.20250000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (23, 2, 'المنتزه', 'Montazah', 31.29500000, 30.01310000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (24, 2, 'سيدي جابر', 'Sidi Gaber', 31.21790000, 29.93950000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (25, 2, 'سموحة', 'Smouha', 31.20460000, 29.95400000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (26, 2, 'العجمي', 'Agami', 31.14730000, 29.78000000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (27, 2, 'محرم بك', 'Moharam Bek', 31.19560000, 29.91840000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (28, 2, 'مصطفى كامل', 'Mustafa Kamel', 31.23640000, 30.00310000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (29, 2, 'ميامي', 'Miami', 31.26310000, 30.02990000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (30, 1, 'وسط القاهرة', 'Downtown Cairo', 30.04440000, 31.23570000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (31, 1, 'مدينة نصر', 'Nasr City', 30.06260000, 31.34220000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (32, 1, 'المعادي', 'Maadi', 29.96020000, 31.25690000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (33, 1, 'مصر الجديدة', 'Heliopolis', 30.08920000, 31.32140000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (34, 1, 'الزمالك', 'Zamalek', 30.06590000, 31.21950000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (35, 1, 'شبرا', 'Shubra', 30.10570000, 31.24230000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (36, 1, 'عين شمس', 'Ain Shams', 30.10650000, 31.32680000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (37, 1, 'حلوان', 'Helwan', 29.84480000, 31.33370000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (38, 1, 'التجمع الخامس', 'Fifth Settlement', 30.00870000, 31.47330000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (39, 1, 'مدينتي', 'Madinaty', 30.11690000, 31.64380000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (40, 1, 'الرحاب', 'Al Rehab', 30.05860000, 31.49260000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (41, 1, 'العباسية', 'Abbasiya', 30.06310000, 31.27860000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (42, 1, 'المطرية', 'Matareya', 30.12210000, 31.30930000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (43, 1, 'حدائق الأهرام', 'Ahram Gardens', 29.98630000, 31.13730000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (44, 1, 'شبرا الخيمة', 'Shubra El Kheima', 30.12910000, 31.24630000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (45, 3, 'الدقي', 'Dokki', 30.04030000, 31.21060000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (46, 3, 'المهندسين', 'Mohandessin', 30.05740000, 31.19930000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (47, 3, 'الهرم', 'Haram', 29.98990000, 31.15970000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (48, 3, '6 أكتوبر', '6th of October', 29.93600000, 31.01170000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (49, 3, 'الشيخ زايد', 'Sheikh Zayed', 30.01310000, 30.94720000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (50, 3, 'فيصل', 'Faisal', 29.99850000, 31.12800000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (51, 3, 'إمبابة', 'Imbaba', 30.07720000, 31.20250000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (52, 2, 'المنتزه', 'Montazah', 31.29500000, 30.01310000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (53, 2, 'سيدي جابر', 'Sidi Gaber', 31.21790000, 29.93950000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (54, 2, 'سموحة', 'Smouha', 31.20460000, 29.95400000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (55, 2, 'العجمي', 'Agami', 31.14730000, 29.78000000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (56, 2, 'محرم بك', 'Moharam Bek', 31.19560000, 29.91840000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (57, 2, 'مصطفى كامل', 'Mustafa Kamel', 31.23640000, 30.00310000, true);
INSERT INTO public.cities (id, governorate_id, name_ar, name_en, latitude, longitude, is_active) VALUES (58, 2, 'ميامي', 'Miami', 31.26310000, 30.02990000, true);


--
-- Data for Name: districts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (116, 2, 'المنطقة الأولى', 'First Zone');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (117, 2, 'المنطقة السادسة', 'Sixth Zone');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (118, 2, 'المنطقة الثامنة', 'Eighth Zone');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (119, 2, 'زهراء مدينة نصر', 'Zahraa Nasr City');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (120, 2, 'الحي السابع', '7th District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (121, 2, 'الحي العاشر', '10th District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (122, 3, 'المعادي القديمة', 'Old Maadi');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (123, 3, 'ثكنات المعادي', 'Thakanat Maadi');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (124, 3, 'زهراء المعادي', 'Zahraa Maadi');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (125, 3, 'حدائق المعادي', 'Hadayek Maadi');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (126, 3, 'دجلة المعادي', 'Degla Maadi');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (127, 4, 'الكوربة', 'Korba');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (128, 4, 'ميدان تريومف', 'Triumph Square');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (129, 4, 'روكسي', 'Roxy');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (130, 4, 'شيراتون', 'Sheraton');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (131, 4, 'جسر السويس', 'Gesr El Suez');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (132, 9, 'النرجس', 'Al Narges');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (133, 9, 'الياسمين', 'Al Yasmeen');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (134, 9, 'البنفسج', 'Al Bafanseg');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (135, 9, 'اللؤلؤة', 'Al Loloa');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (136, 9, 'المستثمرين', 'Investors');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (137, 9, 'بيت الوطن', 'Beit El Watan');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (138, 16, 'البحوث', 'El Bohooth');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (139, 16, 'ميدان المساحة', 'Mesaha Square');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (140, 16, 'بين السرايات', 'Been El Sarayat');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (141, 16, 'ميدان الدقي', 'Dokki Square');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (142, 17, 'ميدان لبنان', 'Lebanon Square');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (143, 17, 'جامعة الدول العربية', 'Jamiat Al Dowal');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (144, 17, 'ميت عقبة', 'Mit Okba');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (145, 17, 'جزيرة العرب', 'Geziret Al Arab');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (146, 18, 'سهل حمزة', 'Sahl Hamza');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (147, 18, 'العريش', 'El Arish');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (148, 18, 'المريوطية', 'Maryoutia');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (149, 18, 'اللبيني', 'El Labini');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (150, 19, 'الحي المتميز', 'Motamayez District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (151, 19, 'الحي الأول', 'First District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (152, 19, 'الحي الثاني', 'Second District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (153, 19, 'حدائق أكتوبر', 'Hadayek October');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (154, 19, 'جنوب الأحياء', 'South Districts');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (155, 20, 'الحي الأول', 'First District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (156, 20, 'الحي الثاني', 'Second District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (157, 20, 'الحي الحادي عشر', 'Eleventh District');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (158, 20, 'الثورة الخضراء', 'Green Revolution');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (159, 23, 'المندرة', 'Mandara');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (160, 23, 'العصافرة', 'Asafra');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (161, 23, 'أبو قير', 'Abu Qir');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (162, 23, 'المعمورة', 'Maamoura');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (163, 24, 'كليوباترا', 'Cleopatra');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (164, 24, 'مصطفى كامل', 'Mustafa Kamel');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (165, 24, 'رياضة سبورتنج', 'Sporting');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (166, 25, 'فيكتور عمانويل', 'Victor Emmanuel');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (167, 25, 'عزبة سعد', 'Ezbet Saad');
INSERT INTO public.districts (id, city_id, name_ar, name_en) VALUES (168, 25, 'ميدان ألبرت الأول', 'Albert Square');


--
-- Data for Name: subscription_plans; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.subscription_plans (id, name, name_ar, price_monthly, price_yearly, max_ads, max_images_per_ad, features, is_active, sort_order) VALUES (1, 'free', 'مجاني', 0.00, 0.00, 5, 4, '{"analytics": false, "can_boost": false, "verified_badge": false, "priority_support": false}', true, 1);
INSERT INTO public.subscription_plans (id, name, name_ar, price_monthly, price_yearly, max_ads, max_images_per_ad, features, is_active, sort_order) VALUES (2, 'basic', 'أساسي', 99.00, 950.00, 20, 8, '{"analytics": false, "can_boost": false, "verified_badge": true, "priority_support": false}', true, 2);
INSERT INTO public.subscription_plans (id, name, name_ar, price_monthly, price_yearly, max_ads, max_images_per_ad, features, is_active, sort_order) VALUES (3, 'premium', 'بريميوم', 199.00, 1900.00, 50, 12, '{"analytics": true, "can_boost": true, "verified_badge": true, "priority_support": false}', true, 3);
INSERT INTO public.subscription_plans (id, name, name_ar, price_monthly, price_yearly, max_ads, max_images_per_ad, features, is_active, sort_order) VALUES (4, 'business', 'أعمال', 499.00, 4790.00, 999, 20, '{"analytics": true, "can_boost": true, "api_access": true, "verified_badge": true, "priority_support": true}', true, 4);


--
-- Name: app_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.app_versions_id_seq', 4, true);


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.categories_id_seq', 45, true);


--
-- Name: category_fields_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.category_fields_id_seq', 20, true);


--
-- Name: cities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cities_id_seq', 58, true);


--
-- Name: districts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.districts_id_seq', 168, true);


--
-- Name: governorates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.governorates_id_seq', 28, true);


--
-- Name: subscription_plans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.subscription_plans_id_seq', 5, true);


--
-- PostgreSQL database dump complete
--

-- ── Objects outside public ──────────────────────────────────────
SET search_path = public, extensions;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES
  ('ads', 'ads', true, NULL, NULL),
  ('id-documents', 'id-documents', false, 1048576, ARRAY['image/jpeg', 'image/jpg', 'image/png'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Allow authenticated users to upload ads images" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'ads'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "Allow public select on ads bucket" ON storage.objects AS PERMISSIVE FOR SELECT TO public USING ((bucket_id = 'ads'::text));
CREATE POLICY "Allow users to delete their own ads images" ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated USING (((bucket_id = 'ads'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "Auth Users Delete" ON storage.objects AS PERMISSIVE FOR DELETE TO public USING (((bucket_id = 'ads'::text) AND (auth.role() = 'authenticated'::text)));
CREATE POLICY "Auth Users Update" ON storage.objects AS PERMISSIVE FOR UPDATE TO public USING (((bucket_id = 'ads'::text) AND (auth.role() = 'authenticated'::text))) WITH CHECK (((bucket_id = 'ads'::text) AND (auth.role() = 'authenticated'::text)));
CREATE POLICY "Auth Users Upload" ON storage.objects AS PERMISSIVE FOR INSERT TO public WITH CHECK (((bucket_id = 'ads'::text) AND (auth.role() = 'authenticated'::text)));
CREATE POLICY "Public Access" ON storage.objects AS PERMISSIVE FOR SELECT TO public USING ((bucket_id = 'ads'::text));

SELECT cron.schedule('expire-ads', '0 * * * *', '
  UPDATE public.ads SET status = ''expired''
  WHERE  status = ''active'' AND expires_at < NOW() AND deleted_at IS NULL;
');
SELECT cron.schedule('expire-boosts', '5 * * * *', '
  UPDATE public.ads SET is_featured = FALSE
  WHERE  is_featured = TRUE AND NOT EXISTS (
    SELECT 1 FROM public.ad_boosts
    WHERE  ad_id = ads.id AND boost_type = ''featured'' AND expires_at > NOW()
  );
');
SELECT cron.schedule('expire-urgent', '10 * * * *', '
  UPDATE public.ads SET is_urgent = FALSE
  WHERE  is_urgent = TRUE AND NOT EXISTS (
    SELECT 1 FROM public.ad_boosts
    WHERE  ad_id = ads.id AND boost_type = ''urgent'' AND expires_at > NOW()
  );
');
SELECT cron.schedule('expire-otps', '*/15 * * * *', '
  UPDATE public.user_verifications SET status = ''expired''
  WHERE  status = ''pending'' AND expires_at < NOW();
');
SELECT cron.schedule('cleanup-sessions', '0 3 * * *', '
  DELETE FROM public.user_sessions WHERE expires_at < NOW() - INTERVAL ''7 days'';
');
SELECT cron.schedule('cleanup-stale-transactions', '0 * * * *', '
    UPDATE transactions
    SET
      status = ''expired'',
      updated_at = now()
    WHERE
      status = ''pending''
      AND created_at < now() - interval ''2 hours'';
  ');
