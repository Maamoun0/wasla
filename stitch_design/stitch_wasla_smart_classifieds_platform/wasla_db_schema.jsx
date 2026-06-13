import { useState, useMemo } from "react";

const C = {
  p50:"#E4F4F6",p100:"#B8E2E6",p200:"#74C4CC",
  p600:"#0D7A84",p700:"#0A606A",p900:"#032B30",
  a50:"#FEF5E4",a500:"#E89510",a600:"#C97C0C",
  n0:"#FFFFFF",n50:"#F9F7F3",n100:"#F0EDE7",n200:"#EAE4DA",
  n300:"#C9C2B8",n400:"#B0A89C",n500:"#8A8278",
  n600:"#6E6459",n700:"#4E473E",n900:"#161210",
  green:"#16A34A",red:"#DC2626",
};

const D = {
  auth:  {bg:"#EDE9FE",fg:"#5B21B6",ar:"المصادقة والمستخدمون",icon:"🔐"},
  geo:   {bg:"#DCFCE7",fg:"#15803D",ar:"الجغرافيا",icon:"📍"},
  cat:   {bg:"#FEF9C3",fg:"#854D0E",ar:"الأقسام والحقول",icon:"🗂️"},
  ads:   {bg:"#FEE2E2",fg:"#B91C1C",ar:"الإعلانات",icon:"📋"},
  inter: {bg:"#E0F2FE",fg:"#0369A1",ar:"التفاعلات",icon:"💬"},
  pay:   {bg:"#FEF5E4",fg:"#C97C0C",ar:"المدفوعات",icon:"💳"},
  notif: {bg:"#F3E8FF",fg:"#7C3AED",ar:"الإشعارات",icon:"🔔"},
  sys:   {bg:"#F1F5F9",fg:"#475569",ar:"النظام",icon:"⚙️"},
};

// ═══════════════════════════════════════════
//  SCHEMA — 34 جدول
// ═══════════════════════════════════════════
const S = {
  users:{d:"auth",ar:"المستخدمون",desc:"الجدول المركزي لجميع الحسابات",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:"المعرّف الفريد"},
      {n:"email",t:"VARCHAR(255)",nn:1,uq:1,desc:"البريد الإلكتروني"},
      {n:"phone",t:"VARCHAR(20)",uq:1,desc:"رقم هاتف مصري"},
      {n:"password_hash",t:"VARCHAR(255)",desc:"null لتسجيل اجتماعي"},
      {n:"full_name",t:"VARCHAR(100)",nn:1,desc:"الاسم الكامل"},
      {n:"avatar_url",t:"TEXT",desc:"صورة الملف الشخصي"},
      {n:"bio",t:"TEXT",desc:"نبذة شخصية"},
      {n:"user_type",t:"ENUM",nn:1,def:"regular",desc:"regular|business|moderator|admin"},
      {n:"status",t:"ENUM",nn:1,def:"pending",desc:"active|suspended|deleted|pending_verification"},
      {n:"is_phone_verified",t:"BOOLEAN",nn:1,def:"false",desc:""},
      {n:"is_email_verified",t:"BOOLEAN",nn:1,def:"false",desc:""},
      {n:"is_id_verified",t:"BOOLEAN",nn:1,def:"false",desc:"الرقم القومي"},
      {n:"trust_score",t:"DECIMAL(3,2)",nn:1,def:"0.00",desc:"0–5 محسوبة تلقائياً"},
      {n:"city_id",t:"INT",fk:"cities.id",desc:"المدينة الافتراضية"},
      {n:"last_active_at",t:"TIMESTAMP",desc:"آخر نشاط"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"updated_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"deleted_at",t:"TIMESTAMP",desc:"soft delete"},
    ]},
  user_auth_providers:{d:"auth",ar:"مزودو المصادقة",desc:"Google / Facebook / Apple",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"provider",t:"ENUM",nn:1,desc:"google|facebook|apple"},
      {n:"provider_user_id",t:"VARCHAR(255)",nn:1,desc:"معرّف عند المزوّد"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  user_sessions:{d:"auth",ar:"جلسات المستخدمين",desc:"JWT sessions لكل جهاز",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"token_hash",t:"VARCHAR(255)",nn:1,uq:1,desc:"هاش الـ Token"},
      {n:"device_info",t:"JSONB",desc:"{platform, model, app_version}"},
      {n:"ip_address",t:"INET",desc:""},
      {n:"expires_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"last_used_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  user_verifications:{d:"auth",ar:"طلبات التحقق",desc:"OTP الهاتف — البريد — الرقم القومي",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"type",t:"ENUM",nn:1,desc:"phone_otp|email_token|national_id"},
      {n:"code_hash",t:"VARCHAR(255)",desc:"OTP مشفّر"},
      {n:"document_url",t:"TEXT",desc:"صورة وثيقة الهوية"},
      {n:"status",t:"ENUM",nn:1,desc:"pending|approved|rejected|expired"},
      {n:"attempts",t:"SMALLINT",nn:1,def:"0",desc:"عدد المحاولات"},
      {n:"expires_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"verified_at",t:"TIMESTAMP",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  roles:{d:"auth",ar:"الأدوار",desc:"تعريف أدوار النظام",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"name",t:"VARCHAR(50)",nn:1,uq:1,desc:"moderator, ad_reviewer..."},
      {n:"description",t:"TEXT",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  user_roles:{d:"auth",ar:"أدوار المستخدمين",desc:"ربط مستخدمين × أدوار — M2M",
    cols:[
      {n:"user_id",t:"UUID",pk:1,fk:"users.id",nn:1,desc:""},
      {n:"role_id",t:"UUID",pk:1,fk:"roles.id",nn:1,desc:""},
      {n:"granted_by",t:"UUID",fk:"users.id",desc:"من منح الدور"},
      {n:"granted_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  permissions:{d:"auth",ar:"الصلاحيات",desc:"صلاحيات دقيقة: ads.create, users.ban...",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"name",t:"VARCHAR(100)",nn:1,uq:1,desc:"ads.create|ads.approve|users.ban|users.verify"},
      {n:"description",t:"TEXT",desc:""},
      {n:"category",t:"VARCHAR(50)",nn:1,desc:"ads|users|payments|system"},
    ]},
  role_permissions:{d:"auth",ar:"صلاحيات الأدوار",desc:"ربط أدوار × صلاحيات — M2M",
    cols:[
      {n:"role_id",t:"UUID",pk:1,fk:"roles.id",nn:1,desc:""},
      {n:"permission_id",t:"UUID",pk:1,fk:"permissions.id",nn:1,desc:""},
    ]},
  governorates:{d:"geo",ar:"المحافظات",desc:"المحافظات المصرية الـ 27",
    cols:[
      {n:"id",t:"SMALLINT",pk:1,nn:1,desc:""},
      {n:"name_ar",t:"VARCHAR(50)",nn:1,desc:""},
      {n:"name_en",t:"VARCHAR(50)",nn:1,desc:""},
      {n:"code",t:"VARCHAR(5)",nn:1,uq:1,desc:"CAI|ALX|GIZ|..."},
      {n:"is_active",t:"BOOLEAN",nn:1,def:"true",desc:""},
    ]},
  cities:{d:"geo",ar:"المدن والأحياء",desc:"مدن رئيسية وأحياء داخل المحافظات",
    cols:[
      {n:"id",t:"INT",pk:1,nn:1,desc:""},
      {n:"governorate_id",t:"SMALLINT",fk:"governorates.id",nn:1,desc:""},
      {n:"name_ar",t:"VARCHAR(80)",nn:1,desc:""},
      {n:"name_en",t:"VARCHAR(80)",nn:1,desc:""},
      {n:"latitude",t:"DECIMAL(10,8)",desc:""},
      {n:"longitude",t:"DECIMAL(11,8)",desc:""},
      {n:"is_active",t:"BOOLEAN",nn:1,def:"true",desc:""},
    ]},
  districts:{d:"geo",ar:"المناطق",desc:"أحياء ومناطق أصغر داخل المدينة",
    cols:[
      {n:"id",t:"INT",pk:1,nn:1,desc:""},
      {n:"city_id",t:"INT",fk:"cities.id",nn:1,desc:""},
      {n:"name_ar",t:"VARCHAR(80)",nn:1,desc:""},
      {n:"name_en",t:"VARCHAR(80)",desc:""},
    ]},
  categories:{d:"cat",ar:"الأقسام",desc:"هيكل هرمي ذاتي — level 1/2/3",
    cols:[
      {n:"id",t:"INT",pk:1,nn:1,desc:""},
      {n:"parent_id",t:"INT",fk:"categories.id",desc:"null = قسم رئيسي"},
      {n:"name_ar",t:"VARCHAR(80)",nn:1,desc:""},
      {n:"name_en",t:"VARCHAR(80)",nn:1,desc:""},
      {n:"slug",t:"VARCHAR(80)",nn:1,uq:1,desc:"services|jobs|real-estate|vehicles|goods"},
      {n:"icon",t:"VARCHAR(50)",desc:"إيموجي أو اسم أيقونة"},
      {n:"level",t:"SMALLINT",nn:1,desc:"1=رئيسي 2=فرعي 3=تفصيلي"},
      {n:"sort_order",t:"SMALLINT",nn:1,def:"0",desc:""},
      {n:"is_active",t:"BOOLEAN",nn:1,def:"true",desc:""},
    ]},
  category_fields:{d:"cat",ar:"حقول الأقسام",desc:"حقول ديناميكية خاصة بكل قسم",
    cols:[
      {n:"id",t:"INT",pk:1,nn:1,desc:""},
      {n:"category_id",t:"INT",fk:"categories.id",nn:1,desc:""},
      {n:"field_name",t:"VARCHAR(50)",nn:1,desc:"salary|area_sqm|car_year|condition..."},
      {n:"label_ar",t:"VARCHAR(80)",nn:1,desc:""},
      {n:"field_type",t:"ENUM",nn:1,desc:"text|number|select|boolean|range"},
      {n:"options",t:"JSONB",desc:'[{"value":"new","label_ar":"جديد"}]'},
      {n:"is_required",t:"BOOLEAN",nn:1,def:"false",desc:""},
      {n:"is_searchable",t:"BOOLEAN",nn:1,def:"false",desc:"يظهر كفلتر بحث؟"},
      {n:"sort_order",t:"SMALLINT",nn:1,def:"0",desc:""},
    ]},
  ads:{d:"ads",ar:"الإعلانات",desc:"الجدول الأساسي — قلب المنصة",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:"صاحب الإعلان"},
      {n:"category_id",t:"INT",fk:"categories.id",nn:1,desc:""},
      {n:"title",t:"VARCHAR(120)",nn:1,desc:"max 120 حرف"},
      {n:"description",t:"TEXT",nn:1,desc:""},
      {n:"ad_type",t:"ENUM",nn:1,desc:"offering (معروض) | seeking (مطلوب)"},
      {n:"price",t:"DECIMAL(12,2)",desc:"null = مجاني أو بالتفاوض"},
      {n:"price_type",t:"ENUM",nn:1,desc:"fixed|negotiable|free|per_hour|per_month"},
      {n:"currency",t:"VARCHAR(3)",nn:1,def:"EGP",desc:""},
      {n:"city_id",t:"INT",fk:"cities.id",nn:1,desc:""},
      {n:"district_id",t:"INT",fk:"districts.id",desc:""},
      {n:"latitude",t:"DECIMAL(10,8)",desc:"للبحث الجغرافي"},
      {n:"longitude",t:"DECIMAL(11,8)",desc:""},
      {n:"status",t:"ENUM",nn:1,def:"pending",desc:"pending|active|paused|rejected|expired|deleted|sold"},
      {n:"rejection_reason",t:"TEXT",desc:"سبب الرفض"},
      {n:"is_featured",t:"BOOLEAN",nn:1,def:"false",desc:"مميز مدفوع"},
      {n:"is_urgent",t:"BOOLEAN",nn:1,def:"false",desc:"شارة عاجل"},
      {n:"views_count",t:"INT",nn:1,def:"0",desc:""},
      {n:"contacts_count",t:"INT",nn:1,def:"0",desc:""},
      {n:"favorites_count",t:"INT",nn:1,def:"0",desc:""},
      {n:"expires_at",t:"TIMESTAMP",nn:1,desc:"انتهاء صلاحية الإعلان"},
      {n:"refreshed_at",t:"TIMESTAMP",desc:"آخر عملية bump"},
      {n:"published_at",t:"TIMESTAMP",desc:"وقت الموافقة والنشر"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"updated_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"deleted_at",t:"TIMESTAMP",desc:"soft delete"},
    ]},
  ad_media:{d:"ads",ar:"صور الإعلانات",desc:"صور وملفات كل إعلان",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"ad_id",t:"UUID",fk:"ads.id",nn:1,desc:""},
      {n:"url",t:"TEXT",nn:1,desc:"Cloudflare R2 / S3"},
      {n:"thumbnail_url",t:"TEXT",desc:"نسخة مصغّرة"},
      {n:"type",t:"ENUM",nn:1,def:"image",desc:"image|video"},
      {n:"sort_order",t:"SMALLINT",nn:1,def:"0",desc:""},
      {n:"is_primary",t:"BOOLEAN",nn:1,def:"false",desc:"الصورة الرئيسية"},
      {n:"size_bytes",t:"INT",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  ad_fields:{d:"ads",ar:"قيم الحقول",desc:"قيم الحقول الديناميكية لكل إعلان",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"ad_id",t:"UUID",fk:"ads.id",nn:1,desc:""},
      {n:"field_id",t:"INT",fk:"category_fields.id",nn:1,desc:""},
      {n:"value_text",t:"TEXT",desc:"نصي"},
      {n:"value_number",t:"DECIMAL(15,4)",desc:"رقمي"},
      {n:"value_boolean",t:"BOOLEAN",desc:"منطقي"},
      {n:"value_json",t:"JSONB",desc:"معقد / متعدد القيم"},
    ]},
  ad_moderation_log:{d:"ads",ar:"سجل المراجعة",desc:"تاريخ كل قرار مراجعة",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"ad_id",t:"UUID",fk:"ads.id",nn:1,desc:""},
      {n:"moderator_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"action",t:"ENUM",nn:1,desc:"approved|rejected|flagged|suspended|restored"},
      {n:"reason",t:"TEXT",desc:""},
      {n:"previous_status",t:"VARCHAR(30)",nn:1,desc:""},
      {n:"new_status",t:"VARCHAR(30)",nn:1,desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  favorites:{d:"inter",ar:"المفضلة",desc:"إعلانات محفوظة لدى المستخدم",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"ad_id",t:"UUID",fk:"ads.id",nn:1,desc:""},
      {n:"notes",t:"TEXT",desc:"ملاحظات شخصية على الإعلان"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  saved_searches:{d:"inter",ar:"البحوث المحفوظة",desc:"Watchlist — إشعار عند كل إعلان جديد يطابق البحث",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"name",t:"VARCHAR(100)",desc:"اسم البحث (اختياري)"},
      {n:"category_id",t:"INT",fk:"categories.id",desc:""},
      {n:"city_id",t:"INT",fk:"cities.id",desc:""},
      {n:"keywords",t:"VARCHAR(200)",desc:""},
      {n:"filters",t:"JSONB",desc:"{min_price, max_price, ad_type, ...}"},
      {n:"notify_via",t:"ENUM",nn:1,def:"push",desc:"push|email|both"},
      {n:"is_active",t:"BOOLEAN",nn:1,def:"true",desc:""},
      {n:"last_notified_at",t:"TIMESTAMP",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  ad_views:{d:"inter",ar:"مشاهدات الإعلانات",desc:"تتبع كل مشاهدة — للتحليلات",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"ad_id",t:"UUID",fk:"ads.id",nn:1,desc:""},
      {n:"viewer_id",t:"UUID",fk:"users.id",desc:"null للزوار"},
      {n:"ip_address",t:"INET",desc:""},
      {n:"device_type",t:"VARCHAR(20)",desc:"mobile|tablet|desktop"},
      {n:"source",t:"VARCHAR(30)",desc:"search|category|direct|notification|share"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  contact_logs:{d:"inter",ar:"سجل التواصل",desc:"كل ضغط على زر التواصل مع المعلن",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"ad_id",t:"UUID",fk:"ads.id",nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",desc:""},
      {n:"contact_type",t:"ENUM",nn:1,desc:"phone|whatsapp|email"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  reports:{d:"inter",ar:"البلاغات",desc:"بلاغات على إعلانات أو مستخدمين مشبوهين",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"reporter_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"target_type",t:"ENUM",nn:1,desc:"ad|user"},
      {n:"target_id",t:"UUID",nn:1,desc:"id الإعلان أو المستخدم"},
      {n:"reason",t:"ENUM",nn:1,desc:"fraud|duplicate|inappropriate|wrong_category|spam|other"},
      {n:"description",t:"TEXT",desc:""},
      {n:"status",t:"ENUM",nn:1,def:"pending",desc:"pending|reviewed|resolved|dismissed"},
      {n:"reviewed_by",t:"UUID",fk:"users.id",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  reviews:{d:"inter",ar:"التقييمات",desc:"تقييم المستخدمين لبعضهم بعد الصفقة",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"reviewer_id",t:"UUID",fk:"users.id",nn:1,desc:"المقيِّم"},
      {n:"reviewed_user_id",t:"UUID",fk:"users.id",nn:1,desc:"المُقيَّم"},
      {n:"ad_id",t:"UUID",fk:"ads.id",desc:"الإعلان المصدر للتقييم"},
      {n:"rating",t:"SMALLINT",nn:1,desc:"1 إلى 5 نجوم"},
      {n:"comment",t:"TEXT",desc:""},
      {n:"status",t:"ENUM",nn:1,def:"active",desc:"active|hidden|deleted"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  review_responses:{d:"inter",ar:"ردود التقييمات",desc:"رد المُقيَّم على التقييم",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"review_id",t:"UUID",fk:"reviews.id",nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"response",t:"TEXT",nn:1,desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  subscription_plans:{d:"pay",ar:"خطط الاشتراك",desc:"مجاني | أساسي | بريميوم | أعمال",
    cols:[
      {n:"id",t:"INT",pk:1,nn:1,desc:""},
      {n:"name",t:"VARCHAR(50)",nn:1,uq:1,desc:"free|basic|premium|business"},
      {n:"name_ar",t:"VARCHAR(50)",nn:1,desc:""},
      {n:"price_monthly",t:"DECIMAL(8,2)",nn:1,def:"0",desc:"بالجنيه المصري"},
      {n:"price_yearly",t:"DECIMAL(8,2)",nn:1,def:"0",desc:""},
      {n:"max_ads",t:"INT",nn:1,desc:"الحد الأقصى للإعلانات النشطة"},
      {n:"max_images_per_ad",t:"SMALLINT",nn:1,desc:""},
      {n:"features",t:"JSONB",nn:1,desc:"{can_boost, verified_badge, analytics, ...}"},
      {n:"is_active",t:"BOOLEAN",nn:1,def:"true",desc:""},
      {n:"sort_order",t:"SMALLINT",nn:1,def:"0",desc:""},
    ]},
  user_subscriptions:{d:"pay",ar:"اشتراكات المستخدمين",desc:"اشتراكات نشطة ومنتهية",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"plan_id",t:"INT",fk:"subscription_plans.id",nn:1,desc:""},
      {n:"status",t:"ENUM",nn:1,desc:"active|expired|cancelled|trial"},
      {n:"started_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"expires_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"auto_renew",t:"BOOLEAN",nn:1,def:"false",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  ad_boosts:{d:"pay",ar:"تعزيزات الإعلانات",desc:"Boost — تثبيت الإعلان في أعلى النتائج",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"ad_id",t:"UUID",fk:"ads.id",nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"boost_type",t:"ENUM",nn:1,desc:"featured|urgent|bump"},
      {n:"started_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"expires_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  transactions:{d:"pay",ar:"المعاملات المالية",desc:"Paymob / فوري / InstaPay",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"type",t:"ENUM",nn:1,desc:"subscription|ad_boost|credit_purchase"},
      {n:"reference_id",t:"UUID",desc:"يشير لـ subscription أو boost"},
      {n:"amount",t:"DECIMAL(10,2)",nn:1,desc:""},
      {n:"currency",t:"VARCHAR(3)",nn:1,def:"EGP",desc:""},
      {n:"payment_method",t:"ENUM",nn:1,desc:"card|fawry|instapay|vodafone_cash"},
      {n:"payment_gateway",t:"VARCHAR(30)",nn:1,desc:"paymob|fawry"},
      {n:"gateway_transaction_id",t:"VARCHAR(100)",desc:"معرّف عند بوابة الدفع"},
      {n:"status",t:"ENUM",nn:1,desc:"pending|completed|failed|refunded"},
      {n:"metadata",t:"JSONB",desc:"بيانات إضافية من البوابة"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"completed_at",t:"TIMESTAMP",desc:""},
    ]},
  user_credits:{d:"pay",ar:"رصيد المستخدم",desc:"1-to-1 مع users — رصيد داخلي",
    cols:[
      {n:"user_id",t:"UUID",pk:1,fk:"users.id",nn:1,desc:""},
      {n:"balance",t:"DECIMAL(10,2)",nn:1,def:"0.00",desc:"الرصيد بالجنيه"},
      {n:"updated_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  credit_transactions:{d:"pay",ar:"حركات الرصيد",desc:"كل إيداع وسحب من الرصيد الداخلي",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"amount",t:"DECIMAL(10,2)",nn:1,desc:"+ إيداع | - خصم"},
      {n:"type",t:"ENUM",nn:1,desc:"purchase|boost_spend|refund|bonus"},
      {n:"description",t:"VARCHAR(200)",nn:1,desc:""},
      {n:"balance_after",t:"DECIMAL(10,2)",nn:1,desc:"الرصيد بعد العملية"},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  notifications:{d:"notif",ar:"الإشعارات",desc:"كل إشعار يُرسَل لمستخدم",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"type",t:"ENUM",nn:1,desc:"saved_search_match|ad_approved|ad_rejected|new_review|boost_expiring|system"},
      {n:"title",t:"VARCHAR(150)",nn:1,desc:""},
      {n:"body",t:"TEXT",nn:1,desc:""},
      {n:"data",t:"JSONB",desc:"{ad_id, action_url}"},
      {n:"is_read",t:"BOOLEAN",nn:1,def:"false",desc:""},
      {n:"read_at",t:"TIMESTAMP",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  push_tokens:{d:"notif",ar:"رموز الإشعارات",desc:"FCM / APNs tokens لكل جهاز",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"user_id",t:"UUID",fk:"users.id",nn:1,desc:""},
      {n:"token",t:"TEXT",nn:1,uq:1,desc:"FCM أو APNs token"},
      {n:"platform",t:"ENUM",nn:1,desc:"android|ios|web"},
      {n:"is_active",t:"BOOLEAN",nn:1,def:"true",desc:""},
      {n:"updated_at",t:"TIMESTAMP",nn:1,desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  audit_logs:{d:"sys",ar:"سجل العمليات",desc:"كل إجراء يقوم به الأدمن والمشرفون",
    cols:[
      {n:"id",t:"UUID",pk:1,nn:1,desc:""},
      {n:"actor_id",t:"UUID",fk:"users.id",nn:1,desc:"من نفّذ العملية"},
      {n:"action",t:"VARCHAR(80)",nn:1,desc:"user.ban|ad.delete|plan.update..."},
      {n:"target_type",t:"VARCHAR(30)",nn:1,desc:"user|ad|plan|category..."},
      {n:"target_id",t:"UUID",desc:""},
      {n:"changes",t:"JSONB",desc:"{before:{...}, after:{...}}"},
      {n:"ip_address",t:"INET",desc:""},
      {n:"created_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
  app_configs:{d:"sys",ar:"إعدادات التطبيق",desc:"إعدادات ديناميكية من لوحة التحكم",
    cols:[
      {n:"key",t:"VARCHAR(80)",pk:1,nn:1,desc:"max_free_ads|ad_expiry_days|..."},
      {n:"value",t:"JSONB",nn:1,desc:"رقم، نص، أو JSON"},
      {n:"description",t:"TEXT",desc:""},
      {n:"updated_by",t:"UUID",fk:"users.id",desc:""},
      {n:"updated_at",t:"TIMESTAMP",nn:1,desc:""},
    ]},
};

// ═══════════════════════════════════════════
//  USER TYPES & PERMISSIONS
// ═══════════════════════════════════════════
const UT = [
  {id:"guest",   icon:"🌐",ar:"زائر",        en:"Guest",
   color:{bg:"#F1F5F9",fg:"#475569"},
   desc:"مستخدم غير مسجّل — يتصفح فقط",
   limits:"لا حساب — لا تواصل — لا إعلانات",
   p:{browse:1,search:1,detail:1,contact:0,post:0,fav:0,review:0,boost:0,mod:0,admin:0}},
  {id:"regular", icon:"👤",ar:"عادي",         en:"Regular User",
   color:{bg:"#E0F2FE",fg:"#0369A1"},
   desc:"مسجّل ومؤكد الهاتف",
   limits:"5 إعلانات نشطة · 4 صور/إعلان · لا Boost",
   p:{browse:1,search:1,detail:1,contact:1,post:1,fav:1,review:1,boost:0,mod:0,admin:0}},
  {id:"verified",icon:"✅",ar:"موثّق",        en:"Verified User",
   color:{bg:"#FEF9C3",fg:"#854D0E"},
   desc:"مؤكد بالرقم القومي — شارة الثقة",
   limits:"10 إعلانات · 8 صور · شارة ✓ موثّق",
   p:{browse:1,search:1,detail:1,contact:1,post:1,fav:1,review:1,boost:0,mod:0,admin:0}},
  {id:"business",icon:"🏢",ar:"أعمال",        en:"Business",
   color:{bg:"#FEF5E4",fg:"#C97C0C"},
   desc:"مشترك في خطة مدفوعة — نشاط تجاري",
   limits:"50+ إعلان · Boost · لوحة تحليلات",
   p:{browse:1,search:1,detail:1,contact:1,post:1,fav:1,review:1,boost:1,mod:0,admin:0}},
  {id:"moderator",icon:"🔍",ar:"مشرف",        en:"Moderator",
   color:{bg:"#FEE2E2",fg:"#B91C1C"},
   desc:"يراجع الإعلانات ويدير المحتوى",
   limits:"وصول لقائمة المعلّقة · رفع / قبول",
   p:{browse:1,search:1,detail:1,contact:1,post:0,fav:0,review:0,boost:0,mod:1,admin:0}},
  {id:"admin",   icon:"⚙️",ar:"مدير النظام", en:"Admin",
   color:{bg:"#DCFCE7",fg:"#15803D"},
   desc:"صلاحيات كاملة على المنصة",
   limits:"كل الصلاحيات · إدارة الخطط والمستخدمين",
   p:{browse:1,search:1,detail:1,contact:1,post:1,fav:1,review:0,boost:1,mod:1,admin:1}},
];

const PL = [
  {k:"browse",ar:"تصفح الإعلانات"},
  {k:"search",ar:"البحث والتصفية المتقدمة"},
  {k:"detail",ar:"عرض تفاصيل الإعلان كاملاً"},
  {k:"contact",ar:"رؤية معلومات التواصل"},
  {k:"post",ar:"نشر إعلان جديد"},
  {k:"fav",ar:"حفظ المفضلة والـ Watchlist"},
  {k:"review",ar:"كتابة تقييم لمستخدم"},
  {k:"boost",ar:"Boost — تعزيز الإعلانات (مدفوع)"},
  {k:"mod",ar:"مراجعة وإدارة محتوى المنصة"},
  {k:"admin",ar:"إدارة المنصة والمستخدمين كاملاً"},
];

// ═══════════════════════════════════════════
//  RELATIONS — 44 علاقة
// ═══════════════════════════════════════════
const R = [
  {f:"user_auth_providers.user_id",t:"users.id",       type:"N:1", ar:"مستخدم له عدة مزودات مصادقة"},
  {f:"user_sessions.user_id",      t:"users.id",       type:"N:1", ar:"مستخدم له عدة جلسات نشطة"},
  {f:"user_verifications.user_id", t:"users.id",       type:"N:1", ar:"طلبات تحقق متعددة لمستخدم واحد"},
  {f:"user_roles.user_id",         t:"users.id",       type:"M:M", ar:"مستخدمون ↔ أدوار"},
  {f:"user_roles.role_id",         t:"roles.id",       type:"M:M", ar:""},
  {f:"role_permissions.role_id",   t:"roles.id",       type:"M:M", ar:"أدوار ↔ صلاحيات"},
  {f:"role_permissions.permission_id",t:"permissions.id",type:"M:M",ar:""},
  {f:"cities.governorate_id",      t:"governorates.id",type:"N:1", ar:"مدينة تنتمي لمحافظة"},
  {f:"districts.city_id",          t:"cities.id",      type:"N:1", ar:"منطقة تنتمي لمدينة"},
  {f:"users.city_id",              t:"cities.id",      type:"N:1", ar:"مستخدم ينتمي لمدينة"},
  {f:"categories.parent_id",       t:"categories.id",  type:"SELF",ar:"قسم فرعي يتبع قسماً رئيسياً (self-referencing)"},
  {f:"category_fields.category_id",t:"categories.id",  type:"N:1", ar:"حقول ديناميكية خاصة بكل قسم"},
  {f:"ads.user_id",                t:"users.id",       type:"N:1", ar:"مستخدم ينشر عدة إعلانات"},
  {f:"ads.category_id",            t:"categories.id",  type:"N:1", ar:"إعلان ينتمي لقسم"},
  {f:"ads.city_id",                t:"cities.id",      type:"N:1", ar:"إعلان في مدينة"},
  {f:"ads.district_id",            t:"districts.id",   type:"N:1", ar:"إعلان في منطقة"},
  {f:"ad_media.ad_id",             t:"ads.id",         type:"N:1", ar:"إعلان له عدة صور"},
  {f:"ad_fields.ad_id",            t:"ads.id",         type:"N:1", ar:"قيم الحقول الديناميكية لإعلان"},
  {f:"ad_fields.field_id",         t:"category_fields.id",type:"N:1",ar:""},
  {f:"ad_moderation_log.ad_id",    t:"ads.id",         type:"N:1", ar:"سجل مراجعة الإعلان"},
  {f:"ad_moderation_log.moderator_id",t:"users.id",    type:"N:1", ar:"المشرف الذي اتخذ القرار"},
  {f:"favorites.user_id",          t:"users.id",       type:"N:1", ar:""},
  {f:"favorites.ad_id",            t:"ads.id",         type:"N:1", ar:"مستخدم يحفظ إعلانات في المفضلة"},
  {f:"saved_searches.user_id",     t:"users.id",       type:"N:1", ar:"مستخدم يحفظ بحوثاً للإشعارات"},
  {f:"saved_searches.category_id", t:"categories.id",  type:"N:1", ar:""},
  {f:"ad_views.ad_id",             t:"ads.id",         type:"N:1", ar:"تتبع مشاهدات الإعلان"},
  {f:"ad_views.viewer_id",         t:"users.id",       type:"N:1", ar:""},
  {f:"contact_logs.ad_id",         t:"ads.id",         type:"N:1", ar:"كل ضغط على زر التواصل"},
  {f:"contact_logs.user_id",       t:"users.id",       type:"N:1", ar:""},
  {f:"reports.reporter_id",        t:"users.id",       type:"N:1", ar:"مستخدم يبلّغ عن محتوى"},
  {f:"reviews.reviewer_id",        t:"users.id",       type:"N:1", ar:"مستخدم يكتب تقييمات"},
  {f:"reviews.reviewed_user_id",   t:"users.id",       type:"N:1", ar:"مستخدم يُقيَّم من آخرين"},
  {f:"reviews.ad_id",              t:"ads.id",         type:"N:1", ar:"الإعلان المصدر للتقييم"},
  {f:"review_responses.review_id", t:"reviews.id",     type:"N:1", ar:"رد المُقيَّم على التقييم"},
  {f:"user_subscriptions.user_id", t:"users.id",       type:"N:1", ar:"اشتراكات المستخدم"},
  {f:"user_subscriptions.plan_id", t:"subscription_plans.id",type:"N:1",ar:""},
  {f:"ad_boosts.ad_id",            t:"ads.id",         type:"N:1", ar:"إعلان له Boost مدفوع"},
  {f:"ad_boosts.user_id",          t:"users.id",       type:"N:1", ar:""},
  {f:"transactions.user_id",       t:"users.id",       type:"N:1", ar:"معاملات مالية للمستخدم"},
  {f:"user_credits.user_id",       t:"users.id",       type:"1:1", ar:"رصيد واحد لكل مستخدم (one-to-one)"},
  {f:"credit_transactions.user_id",t:"users.id",       type:"N:1", ar:"حركات الرصيد الداخلي"},
  {f:"notifications.user_id",      t:"users.id",       type:"N:1", ar:"إشعارات المستخدم"},
  {f:"push_tokens.user_id",        t:"users.id",       type:"N:1", ar:"أجهزة المستخدم المسجّلة (FCM/APNs)"},
  {f:"audit_logs.actor_id",        t:"users.id",       type:"N:1", ar:"سجل إجراءات الأدمن"},
  {f:"app_configs.updated_by",     t:"users.id",       type:"N:1", ar:"من عدّل الإعداد"},
];

// ═══════════════════════════════════════════
//  COMPONENT
// ═══════════════════════════════════════════
const tableNames = Object.keys(S);
const domainCounts = tableNames.reduce((acc, t) => {
  acc[S[t].d] = (acc[S[t].d] || 0) + 1;
  return acc;
}, {});

export default function WaslaDB() {
  const [tab, setTab] = useState("users");
  const [selTable, setSelTable] = useState("users");
  const [domain, setDomain] = useState("all");
  const [q, setQ] = useState("");

  const filtered = useMemo(() => tableNames.filter(t => {
    if (domain !== "all" && S[t].d !== domain) return false;
    if (q && !t.includes(q.toLowerCase()) && !S[t].ar.includes(q)) return false;
    return true;
  }), [domain, q]);

  const typeCounts = {
    "1:1": R.filter(r=>r.type==="1:1").length,
    "N:1": R.filter(r=>r.type==="N:1").length,
    "M:M": R.filter(r=>r.type==="M:M").length,
    "SELF":R.filter(r=>r.type==="SELF").length,
  };

  const typeStyle = {
    "1:1":{bg:"#DCFCE7",fg:"#15803D"},
    "N:1":{bg:C.p50,     fg:C.p600},
    "M:M":{bg:"#EDE9FE", fg:"#5B21B6"},
    "SELF":{bg:"#FEF9C3",fg:"#854D0E"},
  };

  const colStyle = {fontSize:"12px",padding:"9px 12px",borderBottom:`1px solid ${C.n100}`};

  return (
    <div style={{fontFamily:"'Cairo',sans-serif",direction:"rtl",background:C.n50,minHeight:"100vh",color:C.n900}}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800;900&family=IBM+Plex+Mono:wght@400;600&display=swap');
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
        ::-webkit-scrollbar{width:5px;height:5px;}
        ::-webkit-scrollbar-thumb{background:${C.p200};border-radius:4px;}
        ::-webkit-scrollbar-track{background:transparent;}
      `}</style>

      {/* ── STICKY HEADER ── */}
      <div style={{
        position:"sticky",top:0,zIndex:200,
        background:`linear-gradient(145deg,${C.p900},${C.p700})`,
        padding:"20px 24px 0",
      }}>
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"16px"}}>
          <div>
            <div style={{display:"flex",alignItems:"center",gap:"12px"}}>
              <span style={{fontSize:"20px",fontWeight:900,color:"#FFF"}}>وصلة</span>
              <span style={{background:"rgba(255,255,255,0.15)",color:"rgba(255,255,255,0.75)",padding:"2px 10px",borderRadius:"20px",fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace"}}>
                Database Schema · v1.0
              </span>
            </div>
            <p style={{color:"rgba(255,255,255,0.5)",fontSize:"12px",marginTop:"3px"}}>
              {tableNames.length} جداول · {R.length} علاقة · 8 domains
            </p>
          </div>
          <div style={{display:"flex",gap:"6px",flexWrap:"wrap"}}>
            {Object.entries(D).map(([k,v])=>(
              <div key={k} style={{display:"flex",alignItems:"center",gap:"4px",background:"rgba(255,255,255,0.1)",padding:"3px 9px",borderRadius:"6px"}}>
                <span style={{fontSize:"11px"}}>{v.icon}</span>
                <span style={{fontSize:"11px",color:"rgba(255,255,255,0.65)",fontWeight:600}}>{domainCounts[k]||0}</span>
              </div>
            ))}
          </div>
        </div>
        {/* Tabs */}
        <div style={{display:"flex",gap:"2px"}}>
          {[
            {id:"users",  ar:`المستخدمون والصلاحيات`},
            {id:"tables", ar:`الجداول (${tableNames.length})`},
            {id:"rels",   ar:`العلاقات (${R.length})`},
          ].map(tb=>(
            <button key={tb.id} onClick={()=>setTab(tb.id)} style={{
              background:tab===tb.id?"rgba(255,255,255,0.15)":"transparent",
              border:"none",
              borderBottom:tab===tb.id?`3px solid ${C.a500}`:"3px solid transparent",
              padding:"9px 18px",cursor:"pointer",
              fontSize:"13px",fontFamily:"'Cairo',sans-serif",fontWeight:tab===tb.id?700:500,
              color:tab===tb.id?"#FFF":"rgba(255,255,255,0.55)",
              borderRadius:"6px 6px 0 0",transition:"all 0.15s",
            }}>{tb.ar}</button>
          ))}
        </div>
      </div>

      <div style={{maxWidth:"1140px",margin:"0 auto",padding:"24px 20px 60px"}}>

        {/* ══════════ TAB 1: USERS ══════════ */}
        {tab==="users" && (
          <div>
            <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:"14px",marginBottom:"28px"}}>
              {UT.map(u=>(
                <div key={u.id} style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden"}}>
                  <div style={{background:u.color.bg,padding:"14px 16px",display:"flex",alignItems:"center",gap:"10px"}}>
                    <span style={{fontSize:"22px"}}>{u.icon}</span>
                    <div>
                      <div style={{fontSize:"15px",fontWeight:800,color:u.color.fg}}>{u.ar}</div>
                      <div style={{fontSize:"10px",fontFamily:"'IBM Plex Mono',monospace",color:u.color.fg,opacity:0.7}}>{u.en}</div>
                    </div>
                  </div>
                  <div style={{padding:"12px 16px"}}>
                    <p style={{fontSize:"12px",color:C.n600,lineHeight:1.65,marginBottom:"10px"}}>{u.desc}</p>
                    <div style={{background:C.n50,borderRadius:"7px",padding:"7px 10px",fontSize:"11px",color:C.n500,fontWeight:600}}>{u.limits}</div>
                  </div>
                </div>
              ))}
            </div>

            {/* Permissions Matrix */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden"}}>
              <div style={{padding:"14px 18px",borderBottom:`1px solid ${C.n100}`,background:C.n50,display:"flex",alignItems:"center",justifyContent:"space-between"}}>
                <div>
                  <h3 style={{fontSize:"15px",fontWeight:800,color:C.n900}}>مصفوفة الصلاحيات الكاملة</h3>
                  <p style={{fontSize:"11px",color:C.n500,marginTop:"2px"}}>✓ مسموح &nbsp;·&nbsp; ✗ غير مسموح</p>
                </div>
              </div>
              <div style={{overflowX:"auto"}}>
                <table style={{width:"100%",borderCollapse:"collapse",fontSize:"12px"}}>
                  <thead>
                    <tr style={{background:C.n50}}>
                      <th style={{...colStyle,textAlign:"right",fontWeight:700,color:C.n600,minWidth:"200px",borderBottom:`2px solid ${C.n200}`}}>الصلاحية</th>
                      {UT.map(u=>(
                        <th key={u.id} style={{...colStyle,textAlign:"center",fontWeight:700,color:u.color.fg,whiteSpace:"nowrap",borderBottom:`2px solid ${C.n200}`}}>
                          {u.icon} {u.ar}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {PL.map((p,i)=>(
                      <tr key={p.k} style={{background:i%2===0?C.n0:C.n50}}>
                        <td style={{...colStyle,fontWeight:600,color:C.n700}}>{p.ar}</td>
                        {UT.map(u=>(
                          <td key={u.id} style={{...colStyle,textAlign:"center"}}>
                            {u.p[p.k]
                              ? <span style={{color:C.green,fontSize:"15px",fontWeight:700}}>✓</span>
                              : <span style={{color:C.n300,fontSize:"15px"}}>✗</span>}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* ══════════ TAB 2: TABLES ══════════ */}
        {tab==="tables" && (
          <div style={{display:"grid",gridTemplateColumns:"250px 1fr",gap:"18px"}}>

            {/* Sidebar */}
            <div style={{display:"flex",flexDirection:"column",gap:"10px"}}>
              <div style={{display:"flex",alignItems:"center",gap:"8px",background:C.n0,border:`1.5px solid ${C.n200}`,borderRadius:"10px",padding:"8px 12px"}}>
                <span style={{color:C.n400,fontSize:"14px"}}>🔍</span>
                <input value={q} onChange={e=>setQ(e.target.value)} placeholder="بحث في الجداول..."
                  style={{border:"none",background:"transparent",outline:"none",fontSize:"13px",fontFamily:"'Cairo',sans-serif",color:C.n800,flex:1,direction:"rtl"}}/>
              </div>

              <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",overflow:"hidden"}}>
                <div style={{padding:"8px 12px",background:C.n50,borderBottom:`1px solid ${C.n100}`,fontSize:"10px",fontWeight:700,color:C.n500,letterSpacing:"0.07em",fontFamily:"'IBM Plex Mono',monospace"}}>
                  DOMAINS
                </div>
                {[{k:"all",ar:"الكل",icon:"📦",count:tableNames.length}, ...Object.entries(D).map(([k,v])=>({k,ar:v.ar,icon:v.icon,count:domainCounts[k]||0}))].map((item,i,arr)=>(
                  <button key={item.k} onClick={()=>setDomain(item.k)} style={{
                    width:"100%",padding:"8px 12px",display:"flex",justifyContent:"space-between",alignItems:"center",
                    background:domain===item.k?(item.k==="all"?C.p50:D[item.k]?.bg||C.p50):"transparent",
                    border:"none",borderBottom:i<arr.length-1?`1px solid ${C.n100}`:"none",
                    cursor:"pointer",fontSize:"12px",fontFamily:"'Cairo',sans-serif",
                    fontWeight:domain===item.k?700:400,
                    color:domain===item.k?(item.k==="all"?C.p600:D[item.k]?.fg||C.p600):C.n600,
                  }}>
                    <span style={{display:"flex",alignItems:"center",gap:"6px"}}><span>{item.icon}</span>{item.ar}</span>
                    <span style={{fontSize:"10px",padding:"1px 7px",borderRadius:"10px",background:domain===item.k?"rgba(0,0,0,0.1)":C.n100,fontWeight:700}}>{item.count}</span>
                  </button>
                ))}
              </div>

              <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",overflow:"hidden",maxHeight:"420px",overflowY:"auto"}}>
                {filtered.map((t,i)=>{
                  const tbl=S[t]; const dm=D[tbl.d]; const isSel=selTable===t;
                  return (
                    <button key={t} onClick={()=>setSelTable(t)} style={{
                      width:"100%",padding:"9px 12px",textAlign:"right",
                      background:isSel?dm.bg:"transparent",
                      border:"none",borderBottom:i<filtered.length-1?`1px solid ${C.n100}`:"none",
                      cursor:"pointer",display:"flex",flexDirection:"column",gap:"1px",
                    }}>
                      <div style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}>
                        <span style={{fontSize:"12px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:isSel?700:400,color:isSel?dm.fg:C.n700}}>{t}</span>
                        <span style={{fontSize:"10px",background:isSel?`${dm.fg}22`:C.n100,color:isSel?dm.fg:C.n500,padding:"1px 6px",borderRadius:"8px",fontWeight:600}}>{tbl.cols.length}</span>
                      </div>
                      <span style={{fontSize:"11px",color:isSel?dm.fg:C.n500,opacity:0.9}}>{tbl.ar}</span>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Table Detail */}
            {selTable && S[selTable] && (() => {
              const tbl=S[selTable]; const dm=D[tbl.d];
              const fkCols=tbl.cols.filter(c=>c.fk);
              return (
                <div style={{display:"flex",flexDirection:"column",gap:"14px"}}>
                  {/* Header */}
                  <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden"}}>
                    <div style={{background:dm.bg,padding:"16px 20px",display:"flex",alignItems:"flex-start",justifyContent:"space-between"}}>
                      <div>
                        <span style={{fontSize:"10px",fontFamily:"'IBM Plex Mono',monospace",background:`${dm.fg}22`,color:dm.fg,padding:"2px 8px",borderRadius:"5px",fontWeight:700}}>{dm.icon} {dm.ar}</span>
                        <h2 style={{fontSize:"20px",fontWeight:900,color:dm.fg,marginTop:"6px",fontFamily:"'IBM Plex Mono',monospace"}}>{selTable}</h2>
                        <p style={{fontSize:"13px",color:dm.fg,opacity:0.8,marginTop:"3px"}}>{tbl.ar} — {tbl.desc}</p>
                      </div>
                      <div style={{display:"flex",gap:"8px"}}>
                        {[
                          {n:tbl.cols.length,label:"أعمدة"},
                          {n:fkCols.length,  label:"FK"},
                          {n:tbl.cols.filter(c=>c.pk).length,label:"PK"},
                          {n:tbl.cols.filter(c=>c.uq).length,label:"UNIQUE"},
                        ].map(s=>(
                          <div key={s.label} style={{textAlign:"center",background:`${dm.fg}18`,padding:"8px 12px",borderRadius:"10px",minWidth:"52px"}}>
                            <div style={{fontSize:"18px",fontWeight:900,color:dm.fg}}>{s.n}</div>
                            <div style={{fontSize:"10px",color:dm.fg,opacity:0.7,fontFamily:"'IBM Plex Mono',monospace"}}>{s.label}</div>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* Columns Table */}
                    <div style={{overflowX:"auto"}}>
                      <table style={{width:"100%",borderCollapse:"collapse",fontSize:"12px"}}>
                        <thead>
                          <tr style={{background:C.n50}}>
                            {["العمود","النوع / المرجع","Nullable","قيود","الوصف"].map(h=>(
                              <th key={h} style={{padding:"9px 12px",textAlign:"right",fontWeight:700,color:C.n600,borderBottom:`1.5px solid ${C.n200}`,whiteSpace:"nowrap",fontSize:"11px"}}>{h}</th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {tbl.cols.map((col,i)=>(
                            <tr key={col.n} style={{background:i%2===0?C.n0:C.n50}}>
                              <td style={{...colStyle,whiteSpace:"nowrap"}}>
                                <div style={{display:"flex",alignItems:"center",gap:"5px"}}>
                                  {col.pk && <span style={{fontSize:"9px",background:"#FEF9C3",color:"#854D0E",padding:"1px 5px",borderRadius:"4px",fontWeight:800,fontFamily:"'IBM Plex Mono',monospace"}}>PK</span>}
                                  {col.fk && !col.pk && <span style={{fontSize:"9px",background:C.p50,color:C.p600,padding:"1px 5px",borderRadius:"4px",fontWeight:800,fontFamily:"'IBM Plex Mono',monospace"}}>FK</span>}
                                  <span style={{fontFamily:"'IBM Plex Mono',monospace",fontWeight:col.pk?700:500,color:col.pk?"#854D0E":C.n800,fontSize:"12px"}}>{col.n}</span>
                                </div>
                              </td>
                              <td style={{...colStyle,whiteSpace:"nowrap"}}>
                                {col.fk
                                  ? <span style={{fontFamily:"'IBM Plex Mono',monospace",color:C.p600,fontWeight:600}}>→ {col.fk}</span>
                                  : <span style={{fontFamily:"'IBM Plex Mono',monospace",color:C.n500}}>{col.t}</span>
                                }
                              </td>
                              <td style={{...colStyle,textAlign:"center"}}>
                                {col.nn
                                  ? <span style={{color:C.red,fontWeight:700,fontSize:"11px"}}>NOT NULL</span>
                                  : <span style={{color:C.n400,fontSize:"11px"}}>nullable</span>}
                              </td>
                              <td style={{...colStyle,whiteSpace:"nowrap"}}>
                                <div style={{display:"flex",gap:"4px",flexWrap:"wrap"}}>
                                  {col.uq && <span style={{fontSize:"9px",background:"#DCFCE7",color:C.green,padding:"1px 5px",borderRadius:"4px",fontWeight:700,fontFamily:"'IBM Plex Mono',monospace"}}>UNIQUE</span>}
                                  {col.def!==undefined && <span style={{fontSize:"9px",background:C.n100,color:C.n600,padding:"1px 5px",borderRadius:"4px",fontFamily:"'IBM Plex Mono',monospace"}}>={col.def}</span>}
                                </div>
                              </td>
                              <td style={{...colStyle,color:C.n500,maxWidth:"220px",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>
                                {col.desc||"—"}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>

                  {/* FK Summary */}
                  {fkCols.length > 0 && (
                    <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",overflow:"hidden"}}>
                      <div style={{padding:"10px 16px",background:C.p50,borderBottom:`1px solid ${C.p100}`}}>
                        <span style={{fontSize:"12px",fontWeight:800,color:C.p600}}>🔗 Foreign Keys — العلاقات الخارجية</span>
                      </div>
                      <div style={{padding:"12px 14px",display:"flex",flexDirection:"column",gap:"7px"}}>
                        {fkCols.map(col=>(
                          <div key={col.n} style={{display:"flex",alignItems:"center",gap:"10px",background:C.n50,borderRadius:"8px",padding:"9px 12px",fontSize:"12px"}}>
                            <span style={{fontFamily:"'IBM Plex Mono',monospace",color:C.n700,fontWeight:600}}>{selTable}.<span style={{color:C.n900}}>{col.n}</span></span>
                            <span style={{color:C.a500,fontWeight:900,fontSize:"16px"}}>→</span>
                            <span style={{fontFamily:"'IBM Plex Mono',monospace",color:C.p600,fontWeight:700}}>{col.fk}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              );
            })()}
          </div>
        )}

        {/* ══════════ TAB 3: RELATIONS ══════════ */}
        {tab==="rels" && (
          <div>
            {/* Type stats */}
            <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:"12px",marginBottom:"24px"}}>
              {[
                {type:"1:1", label:"One-to-One",  desc:"رصيد ↔ مستخدم"},
                {type:"N:1", label:"Many-to-One", desc:"إعلانات ← مستخدم"},
                {type:"M:M", label:"Many-to-Many",desc:"مستخدمون ↔ أدوار"},
                {type:"SELF",label:"Self-Ref",    desc:"أقسام ← أقسام"},
              ].map(s=>{
                const ts=typeStyle[s.type];
                return (
                  <div key={s.type} style={{background:ts.bg,borderRadius:"12px",padding:"16px",textAlign:"center"}}>
                    <div style={{fontSize:"26px",fontWeight:900,color:ts.fg}}>{typeCounts[s.type]}</div>
                    <div style={{fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:700,color:ts.fg,marginTop:"2px"}}>{s.type}</div>
                    <div style={{fontSize:"11px",color:ts.fg,opacity:0.8,marginTop:"3px"}}>{s.label}</div>
                    <div style={{fontSize:"10px",color:ts.fg,opacity:0.6,marginTop:"2px"}}>{s.desc}</div>
                  </div>
                );
              })}
            </div>

            {/* Relations grouped by source domain */}
            {Object.entries(D).map(([dk,dv])=>{
              const domRels = R.filter(r => S[r.f.split(".")[0]]?.d === dk && r.ar);
              if (!domRels.length) return null;
              return (
                <div key={dk} style={{marginBottom:"14px",background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden"}}>
                  <div style={{background:dv.bg,padding:"11px 16px",display:"flex",alignItems:"center",gap:"10px"}}>
                    <span style={{fontSize:"15px"}}>{dv.icon}</span>
                    <span style={{fontSize:"14px",fontWeight:800,color:dv.fg}}>{dv.ar}</span>
                    <span style={{fontSize:"11px",color:dv.fg,opacity:0.65,marginRight:"auto"}}>{domRels.length} علاقة</span>
                  </div>
                  <div style={{padding:"10px 14px",display:"flex",flexDirection:"column",gap:"7px"}}>
                    {domRels.map((r,i)=>{
                      const ts = typeStyle[r.type]||{bg:C.n100,fg:C.n600};
                      return (
                        <div key={i} style={{display:"flex",alignItems:"center",gap:"10px",background:C.n50,borderRadius:"8px",padding:"9px 12px",flexWrap:"wrap"}}>
                          <span style={{fontSize:"10px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:800,color:ts.fg,background:ts.bg,padding:"2px 8px",borderRadius:"5px",whiteSpace:"nowrap"}}>{r.type}</span>
                          <span style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.n700,fontWeight:600,whiteSpace:"nowrap"}}>{r.f}</span>
                          <span style={{color:C.a500,fontWeight:900,fontSize:"14px"}}>→</span>
                          <span style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.p600,fontWeight:700,whiteSpace:"nowrap"}}>{r.t}</span>
                          {r.ar && <span style={{fontSize:"12px",color:C.n500,marginRight:"auto"}}>{r.ar}</span>}
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}

            {/* Summary legend */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",padding:"16px 20px",marginTop:"8px"}}>
              <div style={{fontSize:"12px",fontWeight:800,color:C.n700,marginBottom:"12px"}}>دليل قراءة العلاقات</div>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"10px"}}>
                {[
                  {type:"1:1", exp:"كل مستخدم له سجل رصيد واحد بالضبط، ولا يمكن أن يكون لمستخدمين رصيد واحد."},
                  {type:"N:1", exp:"عدة سجلات في الجدول المصدر تشير لسجل واحد في الجدول الهدف (مثلاً: عدة إعلانات لمستخدم واحد)."},
                  {type:"M:M", exp:"جدول وسيط يربط بين جدولين. مثلاً: مستخدم له أدوار متعددة، ودور يُعطى لمستخدمين متعددين."},
                  {type:"SELF",exp:"الجدول يشير لنفسه. مثلاً: قسم رئيسي وأقسام فرعية كلها في نفس جدول categories."},
                ].map(item=>{
                  const ts=typeStyle[item.type];
                  return (
                    <div key={item.type} style={{display:"flex",gap:"10px",alignItems:"flex-start"}}>
                      <span style={{fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:800,color:ts.fg,background:ts.bg,padding:"3px 9px",borderRadius:"5px",whiteSpace:"nowrap",marginTop:"1px"}}>{item.type}</span>
                      <span style={{fontSize:"12px",color:C.n600,lineHeight:1.6}}>{item.exp}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
