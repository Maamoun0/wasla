-- ========================================================================================
-- WASLA CLASSIFIEDS PLATFORM - CREATE AD TRANSACTION PL/PGSQL FUNCTION
-- ========================================================================================

CREATE OR REPLACE FUNCTION public.create_ad_transaction(
  p_user_id UUID,
  p_temp_draft_id VARCHAR(50),
  p_category_id INT,
  p_title VARCHAR(120),
  p_description TEXT,
  p_ad_type public.ad_type_enum,
  p_price DECIMAL(12,2),
  p_price_type public.price_type_enum,
  p_city_id INT,
  p_district_id INT,
  p_latitude DECIMAL(10,8),
  p_longitude DECIMAL(11,8),
  p_ai_risk_level VARCHAR(20),
  p_ai_review_notes TEXT,
  p_images JSONB,
  p_fields JSONB
) RETURNS UUID AS $$
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
  )
  WHERE id = v_ad_id;

  RETURN v_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
