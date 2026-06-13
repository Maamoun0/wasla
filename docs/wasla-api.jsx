import { useState, useMemo } from "react";

const C = {
  p50:"#E4F4F6",p100:"#B8E2E6",p200:"#74C4CC",
  p600:"#0D7A84",p700:"#0A606A",p900:"#032B30",
  a50:"#FEF5E4",a500:"#E89510",a600:"#C97C0C",
  n0:"#FFFFFF",n50:"#F9F7F3",n100:"#F0EDE7",n200:"#EAE4DA",
  n400:"#B0A89C",n500:"#8A8278",n600:"#6E6459",n700:"#4E473E",n900:"#161210",
  green:"#16A34A",red:"#DC2626",blue:"#1D4ED8",amber:"#D97706",purple:"#7C3AED",
};

const MS = {
  GET:    {bg:"#DCFCE7",fg:"#15803D"},
  POST:   {bg:"#DBEAFE",fg:"#1D4ED8"},
  PATCH:  {bg:"#FEF3C7",fg:"#D97706"},
  DELETE: {bg:"#FEE2E2",fg:"#DC2626"},
};

const TS = {
  postgrest:{label:"PostgREST",bg:C.p50,   fg:C.p600},
  edge:     {label:"Edge Fn",  bg:C.a50,   fg:C.a600},
  auth:     {label:"Auth API", bg:"#EDE9FE",fg:"#5B21B6"},
  storage:  {label:"Storage",  bg:"#F0F9FF",fg:"#0369A1"},
};

const GROUPS = [
  {id:"auth",          icon:"🔐",ar:"المصادقة",       n:6},
  {id:"users",         icon:"👤",ar:"المستخدمون",     n:8},
  {id:"geo",           icon:"📍",ar:"الجغرافيا",      n:3},
  {id:"catalog",       icon:"🗂️",ar:"الأقسام",        n:4},
  {id:"ads",           icon:"📋",ar:"الإعلانات",      n:10},
  {id:"media",         icon:"📷",ar:"صور الإعلانات",  n:3},
  {id:"interactions",  icon:"💬",ar:"التفاعلات",      n:13},
  {id:"payments",      icon:"💳",ar:"المدفوعات",      n:8},
  {id:"notifications", icon:"🔔",ar:"الإشعارات",      n:5},
  {id:"admin",         icon:"⚙️",ar:"الإدارة",        n:7},
  {id:"storage",       icon:"☁️",ar:"التخزين",        n:3},
];

const EP = [
  // ── AUTH ──
  {g:"auth",m:"POST", p:"/auth/v1/signup",       ar:"إنشاء حساب جديد",                     auth:false,type:"auth",
   body:["email: string","password: string","phone?: string","data.full_name: string"],
   res:["access_token: string","token_type: bearer","user: {id, email}"]},
  {g:"auth",m:"POST", p:"/auth/v1/token",         ar:"تسجيل الدخول بكلمة المرور",            auth:false,type:"auth",
   query:["grant_type=password"],
   body:["email: string","password: string"],
   res:["access_token: string","refresh_token: string","expires_in: int"]},
  {g:"auth",m:"POST", p:"/auth/v1/otp",           ar:"إرسال OTP لرقم الهاتف",                auth:false,type:"auth",
   body:["phone: string (+20xxxxxxxxxx)","channel: sms"],
   res:["message_id: string"]},
  {g:"auth",m:"POST", p:"/auth/v1/verify",        ar:"التحقق من كود OTP",                    auth:false,type:"auth",
   body:["phone: string","token: string (6 digits)","type: sms"],
   res:["access_token: string","user: object"]},
  {g:"auth",m:"POST", p:"/auth/v1/logout",        ar:"تسجيل الخروج",                         auth:true, type:"auth",
   res:["{}"]},
  {g:"auth",m:"GET",  p:"/auth/v1/user",          ar:"بيانات المستخدم الحالي",               auth:true, type:"auth",
   res:["id: uuid","email: string","user_metadata: object","phone: string"]},

  // ── USERS ──
  {g:"users",m:"GET",   p:"/rest/v1/users",       ar:"الملف الشخصي العام لمستخدم",           auth:false,type:"postgrest",
   query:["id=eq.{uuid}","select=id,full_name,avatar_url,trust_score,is_id_verified,city_id,created_at"],
   res:["id","full_name","avatar_url","trust_score","is_id_verified"]},
  {g:"users",m:"PATCH", p:"/rest/v1/users",       ar:"تحديث الملف الشخصي",                   auth:true, type:"postgrest",
   query:["id=eq.{uid}"],
   body:["full_name?: string","avatar_url?: string","bio?: string","city_id?: int"],
   res:["updated user object"]},
  {g:"users",m:"DELETE",p:"/rest/v1/users",       ar:"حذف الحساب (soft delete)",              auth:true, type:"postgrest",
   query:["id=eq.{uid}"],
   note:"يضبط deleted_at = NOW() عبر RLS",
   res:["{}"]},
  {g:"users",m:"POST",  p:"/functions/v1/send-phone-otp",    ar:"إرسال OTP للتحقق من الهاتف",auth:true, type:"edge",
   body:["phone: string (Egyptian +20xxxxxxxxxx)"],
   res:["sent: true","expires_at: timestamp"]},
  {g:"users",m:"POST",  p:"/functions/v1/verify-phone",      ar:"تأكيد OTP الهاتف",           auth:true, type:"edge",
   body:["phone: string","code: string (6 digits)"],
   res:["verified: true","is_phone_verified: true"]},
  {g:"users",m:"POST",  p:"/functions/v1/verify-national-id",ar:"رفع الرقم القومي للتحقق",    auth:true, type:"edge",
   body:["document_url: string (Storage path)","national_id_number: string"],
   res:["status: pending","verification_id: uuid"]},
  {g:"users",m:"GET",   p:"/functions/v1/user-stats",        ar:"إحصائيات حساب المستخدم",     auth:true, type:"edge",
   query:["user_id: uuid"],
   res:["active_ads_count: int","total_views: int","total_contacts: int","avg_rating: decimal","reviews_count: int"]},
  {g:"users",m:"GET",   p:"/rest/v1/users",       ar:"إعلانات معلن بعينه (ملف عام)",          auth:false,type:"postgrest",
   query:["id=eq.{uuid}","select=id,full_name,avatar_url,trust_score,is_id_verified"],
   res:["Public profile + ads list"]},

  // ── GEO ──
  {g:"geo",m:"GET",p:"/rest/v1/governorates",     ar:"كل المحافظات المصرية",                  auth:false,type:"postgrest",
   query:["is_active=eq.true","order=id"],
   res:["id","name_ar","name_en","code"]},
  {g:"geo",m:"GET",p:"/rest/v1/cities",           ar:"مدن محافظة معينة",                      auth:false,type:"postgrest",
   query:["governorate_id=eq.{id}","is_active=eq.true","order=name_ar"],
   res:["id","governorate_id","name_ar","name_en","latitude","longitude"]},
  {g:"geo",m:"GET",p:"/rest/v1/districts",        ar:"مناطق مدينة معينة",                     auth:false,type:"postgrest",
   query:["city_id=eq.{id}","order=name_ar"],
   res:["id","city_id","name_ar","name_en"]},

  // ── CATALOG ──
  {g:"catalog",m:"GET",p:"/rest/v1/categories",         ar:"الأقسام الرئيسية (level 1)",      auth:false,type:"postgrest",
   query:["level=eq.1","is_active=eq.true","order=sort_order"],
   res:["id","name_ar","name_en","slug","icon"]},
  {g:"catalog",m:"GET",p:"/rest/v1/categories",         ar:"الأقسام الفرعية",                 auth:false,type:"postgrest",
   query:["parent_id=eq.{id}","is_active=eq.true","order=sort_order"],
   res:["id","parent_id","name_ar","slug","icon","level"]},
  {g:"catalog",m:"GET",p:"/rest/v1/category_fields",    ar:"حقول قسم معين",                   auth:false,type:"postgrest",
   query:["category_id=eq.{id}","order=sort_order"],
   res:["id","field_name","label_ar","field_type","options","is_required","is_searchable"]},
  {g:"catalog",m:"GET",p:"/functions/v1/category-tree", ar:"شجرة الأقسام الكاملة (متداخلة)",  auth:false,type:"edge",
   res:["Nested JSON: [{id, name_ar, children: [...]}]"]},

  // ── ADS ──
  {g:"ads",m:"GET",   p:"/rest/v1/ads",           ar:"قائمة الإعلانات مع فلاتر",              auth:false,type:"postgrest",
   query:["status=eq.active","city_id=eq.{id}","category_id=eq.{id}","ad_type=eq.offering","is_featured=eq.true","order=is_featured.desc,created_at.desc","limit=20","offset=0",
          "select=id,title,price,price_type,city_id,is_featured,is_urgent,views_count,published_at,ad_media(url,is_primary)"],
   res:["Paginated ad list with primary image"]},
  {g:"ads",m:"GET",   p:"/rest/v1/ads",           ar:"تفاصيل إعلان كامل",                     auth:false,type:"postgrest",
   query:["id=eq.{uuid}","select=*,ad_media(*),ad_fields(*,category_fields(label_ar,field_type)),users(full_name,avatar_url,trust_score,is_id_verified,phone),cities(name_ar),districts(name_ar)"],
   res:["Full ad with nested media, fields, user info, location"]},
  {g:"ads",m:"POST",  p:"/rest/v1/ads",           ar:"نشر إعلان جديد",                        auth:true, type:"postgrest",
   body:["user_id: uuid","category_id: smallint","title: string (max 120)","description: text","ad_type: offering|seeking","price?: decimal","price_type: enum","city_id: int","district_id?: int","latitude?: decimal","longitude?: decimal"],
   res:["id: uuid","status: pending","expires_at: timestamp"]},
  {g:"ads",m:"PATCH", p:"/rest/v1/ads",           ar:"تعديل إعلان",                           auth:true, type:"postgrest",
   query:["id=eq.{uuid}"],
   body:["title?: string","description?: string","price?: decimal","status?: paused|active","district_id?: int"],
   res:["Updated ad object"]},
  {g:"ads",m:"DELETE",p:"/rest/v1/ads",           ar:"حذف إعلان (soft delete)",               auth:true, type:"postgrest",
   query:["id=eq.{uuid}"],
   note:"RLS يتحقق أن المستخدم هو المالك",
   res:["{}"]},
  {g:"ads",m:"GET",   p:"/functions/v1/search-ads",   ar:"بحث متقدم بالعربية + فلاتر",        auth:false,type:"edge",
   query:["q: string","category_id?: id","city_id?: id","min_price?: decimal","max_price?: decimal","ad_type?: enum","page?: int (default 1)","limit?: int (default 20)"],
   res:["ads: []","total: int","page: int","has_more: boolean"]},
  {g:"ads",m:"GET",   p:"/functions/v1/ads-nearby",  ar:"إعلانات قريبة جغرافياً",             auth:false,type:"edge",
   query:["lat: decimal","lng: decimal","radius_km?: int (default 10)","category_id?: id","limit?: int"],
   res:["ads: [{...ad, distance_km: float}] — مرتبة بالمسافة"]},
  {g:"ads",m:"POST",  p:"/functions/v1/refresh-ad",  ar:"رفع الإعلان للأعلى (Bump)",          auth:true, type:"edge",
   body:["ad_id: uuid"],
   res:["refreshed_at: timestamp","success: true"]},
  {g:"ads",m:"GET",   p:"/functions/v1/ad-performance",ar:"تحليلات أداء إعلان",               auth:true, type:"edge",
   query:["ad_id: uuid"],
   res:["views_count","contacts_count","favorites_count","views_by_day: [{date, count}]","contact_type_breakdown: {phone, whatsapp, email}"]},
  {g:"ads",m:"POST",  p:"/functions/v1/mark-sold",   ar:"تحديد الإعلان كـ 'تم البيع'",        auth:true, type:"edge",
   body:["ad_id: uuid"],
   res:["status: sold","sold_at: timestamp"]},

  // ── MEDIA ──
  {g:"media",m:"POST",  p:"/storage/v1/object/ads/{ad_id}/{filename}",ar:"رفع صورة لإعلان",  auth:true, type:"storage",
   body:["Binary image (multipart/form-data)","Max: 5MB — JPEG / PNG / WebP"],
   note:"احفظ الـ URL في جدول ad_media بعد الرفع",
   res:["Key: string (path)","Id: string"]},
  {g:"media",m:"POST",  p:"/rest/v1/ad_media",       ar:"ربط الصورة بجدول الإعلان",           auth:true, type:"postgrest",
   body:["ad_id: uuid","url: text","thumbnail_url?: text","sort_order: smallint","is_primary: boolean"],
   res:["id: uuid","ad_id","url","sort_order","created_at"]},
  {g:"media",m:"DELETE",p:"/rest/v1/ad_media",       ar:"حذف صورة من إعلان",                  auth:true, type:"postgrest",
   query:["id=eq.{uuid}"],
   res:["{}"]},

  // ── INTERACTIONS: FAVORITES ──
  {g:"interactions",m:"GET",   p:"/rest/v1/favorites",ar:"قائمة المفضلة",                     auth:true, type:"postgrest",
   query:["user_id=eq.{uid}","select=*,ads(id,title,price,city_id,status,ad_media(url,is_primary))","order=created_at.desc"],
   res:["Favorites with nested ad data + notes"]},
  {g:"interactions",m:"POST",  p:"/rest/v1/favorites",ar:"إضافة إعلان للمفضلة",               auth:true, type:"postgrest",
   body:["user_id: uuid","ad_id: uuid","notes?: text"],
   res:["id: uuid","created_at"]},
  {g:"interactions",m:"PATCH", p:"/rest/v1/favorites",ar:"تعديل ملاحظة مفضّلة",               auth:true, type:"postgrest",
   query:["id=eq.{uuid}"],
   body:["notes: text"],
   res:["Updated favorite"]},
  {g:"interactions",m:"DELETE",p:"/rest/v1/favorites",ar:"إزالة من المفضلة",                  auth:true, type:"postgrest",
   query:["user_id=eq.{uid}&ad_id=eq.{ad_id}"],
   res:["{}"]},

  // ── INTERACTIONS: WATCHLIST ──
  {g:"interactions",m:"GET",   p:"/rest/v1/saved_searches",ar:"قائمة الـ Watchlist",          auth:true, type:"postgrest",
   query:["user_id=eq.{uid}","order=created_at.desc"],
   res:["id","name","category_id","city_id","keywords","filters","notify_via","is_active","last_notified_at"]},
  {g:"interactions",m:"POST",  p:"/rest/v1/saved_searches",ar:"إنشاء Watchlist جديد",         auth:true, type:"postgrest",
   body:["user_id: uuid","name?: string","category_id?: id","city_id?: id","keywords?: string","filters?: {min_price, max_price, ad_type}","notify_via: push|email|both"],
   res:["id: uuid","created_at"]},
  {g:"interactions",m:"PATCH", p:"/rest/v1/saved_searches",ar:"تعديل Watchlist",               auth:true, type:"postgrest",
   query:["id=eq.{uuid}"],
   body:["is_active?: boolean","notify_via?: enum","filters?: jsonb"],
   res:["Updated watchlist"]},
  {g:"interactions",m:"DELETE",p:"/rest/v1/saved_searches",ar:"حذف Watchlist",                auth:true, type:"postgrest",
   query:["id=eq.{uuid}"],
   res:["{}"]},

  // ── INTERACTIONS: CONTACT + REVIEWS + REPORTS ──
  {g:"interactions",m:"POST",  p:"/rest/v1/contact_logs",  ar:"تسجيل تواصل مع معلن",          auth:false,type:"postgrest",
   body:["ad_id: uuid","user_id?: uuid","contact_type: phone|whatsapp|email"],
   note:"يُزيد contacts_count تلقائياً عبر trigger",
   res:["id: uuid","created_at"]},
  {g:"interactions",m:"GET",   p:"/rest/v1/reviews",       ar:"تقييمات مستخدم",               auth:false,type:"postgrest",
   query:["reviewed_user_id=eq.{uuid}","status=eq.active","order=created_at.desc","select=*,review_responses(response)"],
   res:["id","reviewer_id","rating","comment","created_at","review_responses: []"]},
  {g:"interactions",m:"POST",  p:"/rest/v1/reviews",       ar:"كتابة تقييم",                   auth:true, type:"postgrest",
   body:["reviewer_id: uuid","reviewed_user_id: uuid","ad_id?: uuid","rating: 1-5","comment?: text"],
   note:"تُحدَّث trust_score تلقائياً عبر trigger",
   res:["id: uuid","rating","created_at"]},
  {g:"interactions",m:"POST",  p:"/rest/v1/review_responses",ar:"الرد على تقييم",             auth:true, type:"postgrest",
   body:["review_id: uuid","user_id: uuid","response: text"],
   res:["id: uuid","created_at"]},
  {g:"interactions",m:"POST",  p:"/rest/v1/reports",       ar:"إرسال بلاغ",                    auth:true, type:"postgrest",
   body:["reporter_id: uuid","target_type: ad|user","target_id: uuid","reason: fraud|duplicate|inappropriate|wrong_category|spam|other","description?: text"],
   res:["id: uuid","status: pending"]},

  // ── PAYMENTS ──
  {g:"payments",m:"GET",  p:"/rest/v1/subscription_plans", ar:"خطط الاشتراك المتاحة",         auth:false,type:"postgrest",
   query:["is_active=eq.true","order=sort_order"],
   res:["id","name","name_ar","price_monthly","price_yearly","max_ads","max_images_per_ad","features"]},
  {g:"payments",m:"GET",  p:"/rest/v1/user_subscriptions",  ar:"اشتراكي الحالي",               auth:true, type:"postgrest",
   query:["user_id=eq.{uid}","status=eq.active","select=*,subscription_plans(name,name_ar,features)"],
   res:["plan details + started_at + expires_at + auto_renew"]},
  {g:"payments",m:"POST", p:"/functions/v1/create-payment", ar:"بدء عملية دفع عبر Paymob",     auth:true, type:"edge",
   body:["type: subscription|ad_boost","plan_id?: int","boost_type?: enum","duration_days?: int","ad_id?: uuid","amount: decimal","payment_method: card|fawry|instapay|vodafone_cash"],
   res:["payment_key: string","iframe_url: string (Paymob)","order_id: string"]},
  {g:"payments",m:"POST", p:"/functions/v1/payment-webhook",ar:"استقبال webhook من Paymob",    auth:false,type:"edge",
   body:["Paymob HMAC-signed payload"],
   note:"يتحقق من الـ HMAC signature ثم يُفعّل الاشتراك أو الـ Boost",
   res:["{}"]},
  {g:"payments",m:"GET",  p:"/rest/v1/transactions",        ar:"سجل المعاملات المالية",        auth:true, type:"postgrest",
   query:["user_id=eq.{uid}","order=created_at.desc","limit=20"],
   res:["id","type","amount","currency","payment_method","status","created_at","completed_at"]},
  {g:"payments",m:"GET",  p:"/rest/v1/user_credits",        ar:"رصيدي الداخلي",                auth:true, type:"postgrest",
   query:["user_id=eq.{uid}"],
   res:["user_id","balance: decimal","updated_at"]},
  {g:"payments",m:"GET",  p:"/rest/v1/ad_boosts",           ar:"Boosts نشطة لإعلان",           auth:true, type:"postgrest",
   query:["ad_id=eq.{uuid}","expires_at=gt.now()"],
   res:["id","boost_type","started_at","expires_at"]},
  {g:"payments",m:"POST", p:"/functions/v1/boost-ad",       ar:"تعزيز إعلان (Boost)",          auth:true, type:"edge",
   body:["ad_id: uuid","boost_type: featured|urgent|bump","duration_days?: int"],
   res:["payment_key: string — OR — success: true (إذا بالرصيد)"]},

  // ── NOTIFICATIONS ──
  {g:"notifications",m:"GET",   p:"/rest/v1/notifications", ar:"كل الإشعارات",                auth:true, type:"postgrest",
   query:["user_id=eq.{uid}","order=created_at.desc","limit=30","offset=0"],
   res:["id","type","title","body","data","is_read","read_at","created_at"]},
  {g:"notifications",m:"PATCH", p:"/rest/v1/notifications", ar:"تحديد إشعار كمقروء",          auth:true, type:"postgrest",
   query:["id=eq.{uuid}"],
   body:["is_read: true","read_at: timestamp (NOW())"],
   res:["Updated notification"]},
  {g:"notifications",m:"POST",  p:"/functions/v1/mark-all-read",ar:"تحديد الكل كمقروء",       auth:true, type:"edge",
   res:["updated_count: int"]},
  {g:"notifications",m:"POST",  p:"/rest/v1/push_tokens",   ar:"تسجيل جهاز للإشعارات (FCM)", auth:true, type:"postgrest",
   body:["user_id: uuid","token: text (FCM/APNs)","platform: android|ios|web"],
   res:["id: uuid","created_at"]},
  {g:"notifications",m:"DELETE",p:"/rest/v1/push_tokens",   ar:"إلغاء تسجيل جهاز",            auth:true, type:"postgrest",
   query:["token=eq.{token}"],
   res:["{}"]},

  // ── ADMIN ──
  {g:"admin",m:"GET",  p:"/functions/v1/admin/pending-ads",    ar:"الإعلانات المعلّقة للمراجعة",auth:true,type:"edge",
   query:["page?: int","limit?: int (default 20)"],
   note:"يتطلب user_type = moderator أو admin",
   res:["ads: []","total: int","page: int"]},
  {g:"admin",m:"POST", p:"/functions/v1/admin/approve-ad",     ar:"الموافقة على إعلان",        auth:true, type:"edge",
   body:["ad_id: uuid"],
   res:["status: active","published_at: timestamp"]},
  {g:"admin",m:"POST", p:"/functions/v1/admin/reject-ad",      ar:"رفض إعلان مع سبب",          auth:true, type:"edge",
   body:["ad_id: uuid","reason: string"],
   res:["status: rejected","rejection_reason: string"]},
  {g:"admin",m:"POST", p:"/functions/v1/admin/ban-user",       ar:"حظر مستخدم",                 auth:true, type:"edge",
   body:["user_id: uuid","reason?: string"],
   note:"يتطلب user_type = admin فقط",
   res:["status: suspended"]},
  {g:"admin",m:"GET",  p:"/functions/v1/admin/reports",        ar:"البلاغات المعلّقة",          auth:true, type:"edge",
   query:["status?: pending|reviewed","page?: int"],
   res:["reports: []","total: int"]},
  {g:"admin",m:"POST", p:"/functions/v1/admin/resolve-report", ar:"حل بلاغ",                    auth:true, type:"edge",
   body:["report_id: uuid","action: resolved|dismissed","note?: string"],
   res:["status: resolved|dismissed"]},
  {g:"admin",m:"GET",  p:"/functions/v1/admin/platform-stats", ar:"إحصائيات المنصة الكاملة",   auth:true, type:"edge",
   res:["total_users: int","active_ads: int","daily_new_users: int","daily_new_ads: int","revenue_month: decimal","top_cities: []","top_categories: []"]},

  // ── STORAGE ──
  {g:"storage",m:"POST",p:"/storage/v1/object/ads/{ad_id}/{filename}",    ar:"رفع صورة إعلان (Bucket: ads)",   auth:true,type:"storage",
   body:["multipart/form-data — Max 5MB — JPEG/PNG/WebP"],
   res:["Key: string (path)","Id: string"]},
  {g:"storage",m:"POST",p:"/storage/v1/object/avatars/{uid}/{filename}",  ar:"رفع صورة شخصية (Bucket: avatars)",auth:true,type:"storage",
   body:["multipart/form-data — Max 2MB"],
   res:["Key: string","Id: string"]},
  {g:"storage",m:"POST",p:"/storage/v1/object/documents/{uid}/{filename}",ar:"رفع وثيقة هوية (Bucket: documents — خاص)",auth:true,type:"storage",
   body:["multipart/form-data — Max 10MB — PDF/JPG/PNG"],
   note:"Bucket خاص — يُقرأ فقط عبر Edge Function بعد التحقق",
   res:["Key: string","Id: string"]},
];

const ERRORS = [
  {code:"400",title:"Bad Request",    desc:"البيانات المرسلة غير صحيحة أو ناقصة"},
  {code:"401",title:"Unauthorized",   desc:"JWT Token غير موجود أو منتهي الصلاحية"},
  {code:"403",title:"Forbidden",      desc:"المستخدم لا يملك صلاحية هذه العملية (RLS)"},
  {code:"404",title:"Not Found",      desc:"العنصر غير موجود أو محذوف"},
  {code:"409",title:"Conflict",       desc:"يوجد تعارض — مثلاً: الإيميل مستخدم مسبقاً"},
  {code:"422",title:"Unprocessable",  desc:"البيانات صحيحة الصياغة لكن فاشلة في الـ Validation"},
  {code:"429",title:"Too Many Reqs",  desc:"تجاوز حد الطلبات — Rate Limiting مفعّل"},
  {code:"500",title:"Server Error",   desc:"خطأ داخلي في الـ Edge Function أو قاعدة البيانات"},
];

// ══════════════════════════════════════
//  COMPONENT
// ══════════════════════════════════════
function EndpointCard({ ep, idx }) {
  const [open, setOpen] = useState(false);
  const ms = MS[ep.m];
  const ts = TS[ep.type];
  return (
    <div style={{background:C.n0,border:`1px solid ${open?C.p200:C.n200}`,borderRadius:"12px",overflow:"hidden",transition:"border-color 0.15s"}}>
      <div onClick={()=>setOpen(!open)} style={{
        padding:"12px 16px",cursor:"pointer",display:"flex",alignItems:"center",gap:"10px",
        background:open?C.p50:C.n0,transition:"background 0.15s",
      }}>
        <span style={{fontSize:"11px",fontWeight:800,fontFamily:"'IBM Plex Mono',monospace",
          background:ms.bg,color:ms.fg,padding:"3px 8px",borderRadius:"5px",minWidth:"52px",textAlign:"center",flexShrink:0}}>
          {ep.m}
        </span>
        <span style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.n700,flex:1,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{ep.p}</span>
        <span style={{fontSize:"11px",color:ts.fg,background:ts.bg,padding:"2px 7px",borderRadius:"5px",fontWeight:600,flexShrink:0}}>{ts.label}</span>
        {ep.auth
          ? <span style={{fontSize:"11px",color:C.p600,background:C.p50,padding:"2px 7px",borderRadius:"5px",flexShrink:0}}>🔒</span>
          : <span style={{fontSize:"11px",color:C.n500,background:C.n100,padding:"2px 7px",borderRadius:"5px",flexShrink:0}}>🌐</span>}
        <span style={{color:C.n400,fontSize:"14px",transform:open?"rotate(180deg)":"",transition:"transform 0.2s",flexShrink:0}}>▾</span>
      </div>
      <div style={{fontSize:"13px",color:C.n600,padding:"0 16px 10px",marginTop:"-4px"}}>{ep.ar}</div>

      {open && (
        <div style={{borderTop:`1px solid ${C.n100}`,padding:"14px 16px",background:C.n50,display:"flex",flexDirection:"column",gap:"12px"}}>
          {ep.query && (
            <div>
              <div style={{fontSize:"10px",fontWeight:800,color:C.n500,letterSpacing:"0.07em",marginBottom:"6px"}}>QUERY PARAMS</div>
              {ep.query.map((q,i)=>(
                <div key={i} style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.p700,background:C.p50,borderRadius:"5px",padding:"3px 8px",marginBottom:"3px",display:"inline-block",marginLeft:"4px"}}>{q}</div>
              ))}
            </div>
          )}
          {ep.body && (
            <div>
              <div style={{fontSize:"10px",fontWeight:800,color:C.n500,letterSpacing:"0.07em",marginBottom:"6px"}}>REQUEST BODY</div>
              <div style={{background:"#1E293B",borderRadius:"8px",padding:"10px 14px"}}>
                {ep.body.map((b,i)=>(
                  <div key={i} style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:"#94A3B8",lineHeight:1.8}}>
                    <span style={{color:"#7DD3FC"}}>{b.split(":")[0]}</span>
                    <span style={{color:"#CBD5E1"}}>:{b.split(":").slice(1).join(":")}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
          {ep.res && (
            <div>
              <div style={{fontSize:"10px",fontWeight:800,color:C.n500,letterSpacing:"0.07em",marginBottom:"6px"}}>RESPONSE</div>
              <div style={{background:"#0F172A",borderRadius:"8px",padding:"10px 14px"}}>
                {ep.res.map((r,i)=>(
                  <div key={i} style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:"#86EFAC",lineHeight:1.8}}>{r}</div>
                ))}
              </div>
            </div>
          )}
          {ep.note && (
            <div style={{background:C.a50,border:`1px solid ${C.a500}33`,borderRadius:"7px",padding:"8px 12px",fontSize:"12px",color:C.a600}}>
              💡 {ep.note}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function WaslaAPI() {
  const [tab, setTab] = useState("browser");
  const [activeGroup, setActiveGroup] = useState("auth");
  const [search, setSearch] = useState("");

  const groupEPs = useMemo(()=>EP.filter(e=>e.g===activeGroup),[activeGroup]);
  const filteredEPs = useMemo(()=>{
    if(!search.trim()) return groupEPs;
    const q=search.toLowerCase();
    return groupEPs.filter(e=>e.p.toLowerCase().includes(q)||e.ar.includes(q)||e.m.toLowerCase().includes(q));
  },[groupEPs,search]);

  const totalEPs = EP.length;
  const edgeEPs  = EP.filter(e=>e.type==="edge").length;
  const authEPs  = EP.filter(e=>e.auth).length;

  return (
    <div style={{fontFamily:"'Cairo',sans-serif",direction:"rtl",background:C.n50,minHeight:"100vh",color:C.n900}}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800;900&family=IBM+Plex+Mono:wght@400;600&display=swap');
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
        ::-webkit-scrollbar{width:5px;height:5px;}
        ::-webkit-scrollbar-thumb{background:${C.p200};border-radius:4px;}
      `}</style>

      {/* HEADER */}
      <div style={{background:`linear-gradient(145deg,${C.p900},${C.p700})`,padding:"22px 26px 0",position:"sticky",top:0,zIndex:200}}>
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"16px"}}>
          <div>
            <div style={{display:"flex",alignItems:"center",gap:"12px"}}>
              <span style={{fontSize:"20px",fontWeight:900,color:"#FFF"}}>وصلة</span>
              <span style={{background:"rgba(255,255,255,0.15)",color:"rgba(255,255,255,0.75)",padding:"2px 10px",borderRadius:"20px",fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace"}}>
                API Reference v1.0
              </span>
            </div>
            <p style={{color:"rgba(255,255,255,0.5)",fontSize:"12px",marginTop:"3px"}}>
              {totalEPs} endpoint · {edgeEPs} Edge Functions · {authEPs} محمي بـ JWT
            </p>
          </div>
          <div style={{display:"flex",gap:"8px",flexWrap:"wrap"}}>
            {[
              {label:"PostgREST",bg:"rgba(232,149,16,0.2)",fg:C.a500},
              {label:"Edge Fn",  bg:"rgba(13,122,132,0.3)",fg:"#7DD3FC"},
              {label:"Auth API", bg:"rgba(167,139,250,0.2)",fg:"#C4B5FD"},
              {label:"Storage",  bg:"rgba(56,189,248,0.2)", fg:"#7DD3FC"},
            ].map(b=>(
              <span key={b.label} style={{background:b.bg,border:`1px solid ${b.fg}44`,color:b.fg,padding:"4px 10px",borderRadius:"6px",fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace"}}>{b.label}</span>
            ))}
          </div>
        </div>
        <div style={{display:"flex",gap:"2px"}}>
          {[{id:"overview",ar:"نظرة عامة"},{id:"browser",ar:"متصفح الـ Endpoints"},{id:"errors",ar:"الأخطاء"}].map(t=>(
            <button key={t.id} onClick={()=>setTab(t.id)} style={{
              background:tab===t.id?"rgba(255,255,255,0.15)":"transparent",
              border:"none",borderBottom:tab===t.id?`3px solid ${C.a500}`:"3px solid transparent",
              padding:"9px 18px",cursor:"pointer",fontSize:"13px",fontFamily:"'Cairo',sans-serif",
              fontWeight:tab===t.id?700:500,color:tab===t.id?"#FFF":"rgba(255,255,255,0.55)",
              borderRadius:"6px 6px 0 0",transition:"all 0.15s",
            }}>{t.ar}</button>
          ))}
        </div>
      </div>

      <div style={{maxWidth:"1100px",margin:"0 auto",padding:"24px 20px 60px"}}>

        {/* ══ TAB: OVERVIEW ══ */}
        {tab==="overview" && (
          <div style={{display:"flex",flexDirection:"column",gap:"16px"}}>
            {/* Base URLs */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden"}}>
              <div style={{padding:"14px 18px",background:C.n50,borderBottom:`1px solid ${C.n100}`}}>
                <h3 style={{fontSize:"15px",fontWeight:800,color:C.n900}}>Base URLs</h3>
              </div>
              <div style={{padding:"16px 18px",display:"flex",flexDirection:"column",gap:"10px"}}>
                {[
                  {label:"Auto REST API",    url:"https://[project].supabase.co/rest/v1",     type:"postgrest",desc:"CRUD تلقائي من قاعدة البيانات"},
                  {label:"Edge Functions",   url:"https://[project].supabase.co/functions/v1", type:"edge",    desc:"Business Logic مخصص"},
                  {label:"Auth API",         url:"https://[project].supabase.co/auth/v1",      type:"auth",    desc:"تسجيل الدخول والمصادقة"},
                  {label:"Storage API",      url:"https://[project].supabase.co/storage/v1",   type:"storage", desc:"رفع وإدارة الملفات"},
                ].map(item=>{
                  const ts=TS[item.type];
                  return (
                    <div key={item.label} style={{display:"flex",alignItems:"center",gap:"12px",background:C.n50,borderRadius:"10px",padding:"10px 14px"}}>
                      <span style={{fontSize:"11px",fontWeight:700,color:ts.fg,background:ts.bg,padding:"3px 9px",borderRadius:"6px",minWidth:"80px",textAlign:"center",flexShrink:0}}>{item.label}</span>
                      <code style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.p600,flex:1}}>{item.url}</code>
                      <span style={{fontSize:"12px",color:C.n500}}>{item.desc}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Auth Header */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden"}}>
              <div style={{padding:"14px 18px",background:C.n50,borderBottom:`1px solid ${C.n100}`}}>
                <h3 style={{fontSize:"15px",fontWeight:800,color:C.n900}}>المصادقة — Authentication</h3>
              </div>
              <div style={{padding:"16px 18px"}}>
                <div style={{background:"#0F172A",borderRadius:"10px",padding:"14px 18px",marginBottom:"12px"}}>
                  <div style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:"#94A3B8",lineHeight:2}}>
                    <div><span style={{color:"#7DD3FC"}}>Authorization</span>: Bearer <span style={{color:"#86EFAC"}}>{"{supabase_jwt_token}"}</span></div>
                    <div><span style={{color:"#7DD3FC"}}>apikey</span>: <span style={{color:"#86EFAC"}}>{"{supabase_anon_key}"}</span></div>
                    <div><span style={{color:"#7DD3FC"}}>Content-Type</span>: application/json</div>
                    <div><span style={{color:"#7DD3FC"}}>Prefer</span>: return=representation <span style={{color:"#64748B"}}># للـ POST/PATCH</span></div>
                  </div>
                </div>
                <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"10px"}}>
                  {[
                    {icon:"🌐",label:"Public Endpoints",desc:"لا يحتاج Header — للزوار"},
                    {icon:"🔒",label:"Protected Endpoints",desc:"يحتاج JWT Token صالح"},
                    {icon:"👮",label:"Moderator Only",desc:"user_type = moderator|admin"},
                    {icon:"⚙️",label:"Admin Only",desc:"user_type = admin فقط"},
                  ].map(item=>(
                    <div key={item.label} style={{background:C.n50,borderRadius:"9px",padding:"10px 14px",display:"flex",gap:"8px",alignItems:"flex-start"}}>
                      <span style={{fontSize:"16px"}}>{item.icon}</span>
                      <div>
                        <div style={{fontSize:"12px",fontWeight:700,color:C.n800}}>{item.label}</div>
                        <div style={{fontSize:"11px",color:C.n500}}>{item.desc}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Stats */}
            <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:"12px"}}>
              {[
                {n:totalEPs,      label:"إجمالي الـ Endpoints",  bg:C.p50,  fg:C.p600},
                {n:edgeEPs,       label:"Edge Functions مخصصة",  bg:C.a50,  fg:C.a600},
                {n:EP.filter(e=>e.type==="postgrest").length,label:"PostgREST Auto",bg:"#DCFCE7",fg:"#15803D"},
                {n:EP.filter(e=>!e.auth).length, label:"Endpoints عامة",    bg:"#F1F5F9",fg:"#475569"},
              ].map(s=>(
                <div key={s.label} style={{background:s.bg,borderRadius:"12px",padding:"16px",textAlign:"center"}}>
                  <div style={{fontSize:"26px",fontWeight:900,color:s.fg}}>{s.n}</div>
                  <div style={{fontSize:"12px",color:s.fg,marginTop:"2px"}}>{s.label}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ══ TAB: BROWSER ══ */}
        {tab==="browser" && (
          <div style={{display:"grid",gridTemplateColumns:"220px 1fr",gap:"18px"}}>
            {/* Sidebar */}
            <div>
              <div style={{display:"flex",alignItems:"center",gap:"8px",background:C.n0,border:`1.5px solid ${C.n200}`,borderRadius:"10px",padding:"8px 12px",marginBottom:"10px"}}>
                <span style={{color:C.n400}}>🔍</span>
                <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="بحث في الـ endpoints..." style={{border:"none",background:"transparent",outline:"none",fontSize:"12px",fontFamily:"'Cairo',sans-serif",color:C.n800,flex:1,direction:"rtl"}}/>
              </div>
              <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",overflow:"hidden"}}>
                {GROUPS.map((g,i)=>(
                  <button key={g.id} onClick={()=>{setActiveGroup(g.id);setSearch("");}} style={{
                    width:"100%",padding:"9px 12px",display:"flex",justifyContent:"space-between",alignItems:"center",
                    background:activeGroup===g.id?C.p50:"transparent",
                    border:"none",borderBottom:i<GROUPS.length-1?`1px solid ${C.n100}`:"none",
                    cursor:"pointer",fontSize:"12px",fontFamily:"'Cairo',sans-serif",
                    fontWeight:activeGroup===g.id?700:400,
                    color:activeGroup===g.id?C.p600:C.n600,
                  }}>
                    <span style={{display:"flex",alignItems:"center",gap:"7px"}}>{g.icon} {g.ar}</span>
                    <span style={{fontSize:"10px",background:activeGroup===g.id?C.p100:C.n100,color:activeGroup===g.id?C.p600:C.n500,padding:"1px 7px",borderRadius:"10px",fontWeight:700}}>{g.n}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Endpoint List */}
            <div style={{display:"flex",flexDirection:"column",gap:"8px"}}>
              <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"4px"}}>
                <h3 style={{fontSize:"15px",fontWeight:800,color:C.n900}}>
                  {GROUPS.find(g=>g.id===activeGroup)?.icon} {GROUPS.find(g=>g.id===activeGroup)?.ar}
                </h3>
                <span style={{fontSize:"12px",color:C.n500}}>{filteredEPs.length} endpoints</span>
              </div>
              {filteredEPs.map((ep,i)=><EndpointCard key={i} ep={ep} idx={i}/>)}
              {filteredEPs.length===0 && (
                <div style={{textAlign:"center",padding:"40px",color:C.n400,fontSize:"14px"}}>لا نتائج لهذا البحث</div>
              )}
            </div>
          </div>
        )}

        {/* ══ TAB: ERRORS ══ */}
        {tab==="errors" && (
          <div style={{display:"flex",flexDirection:"column",gap:"12px"}}>
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden",marginBottom:"4px"}}>
              <div style={{padding:"14px 18px",background:C.n50,borderBottom:`1px solid ${C.n100}`}}>
                <h3 style={{fontSize:"15px",fontWeight:800,color:C.n900}}>كودات الأخطاء — HTTP Status Codes</h3>
                <p style={{fontSize:"12px",color:C.n500,marginTop:"2px"}}>استجابة قياسية لكل خطأ: {`{ "error": "message", "code": "ERROR_CODE" }`}</p>
              </div>
              <div style={{overflowX:"auto"}}>
                <table style={{width:"100%",borderCollapse:"collapse",fontSize:"13px"}}>
                  <thead>
                    <tr style={{background:C.n50}}>
                      {["الكود","العنوان","المعنى","الحل"].map(h=>(
                        <th key={h} style={{padding:"10px 16px",textAlign:"right",fontWeight:700,color:C.n600,borderBottom:`1.5px solid ${C.n200}`,fontSize:"11px"}}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {ERRORS.map((e,i)=>{
                      const clr = e.code.startsWith("4")
                        ? (e.code==="401"?{fg:"#1D4ED8",bg:"#DBEAFE"}:e.code==="403"?{fg:"#D97706",bg:"#FEF3C7"}:{fg:"#DC2626",bg:"#FEE2E2"})
                        : {fg:"#DC2626",bg:"#FEE2E2"};
                      return (
                        <tr key={e.code} style={{background:i%2===0?C.n0:C.n50}}>
                          <td style={{padding:"11px 16px",borderBottom:`1px solid ${C.n100}`}}>
                            <span style={{fontFamily:"'IBM Plex Mono',monospace",fontWeight:800,fontSize:"13px",background:clr.bg,color:clr.fg,padding:"3px 10px",borderRadius:"6px"}}>{e.code}</span>
                          </td>
                          <td style={{padding:"11px 16px",borderBottom:`1px solid ${C.n100}`,fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.n700,fontWeight:600}}>{e.title}</td>
                          <td style={{padding:"11px 16px",borderBottom:`1px solid ${C.n100}`,fontSize:"13px",color:C.n600}}>{e.desc}</td>
                          <td style={{padding:"11px 16px",borderBottom:`1px solid ${C.n100}`,fontSize:"12px",color:C.n500}}>
                            {e.code==="401"?"تحديث الـ JWT Token":e.code==="403"?"التحقق من الصلاحيات":e.code==="429"?"Retry بعد X ثانية":"تحقق من الـ Logs"}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Standard Error Format */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",padding:"18px 20px"}}>
              <h4 style={{fontSize:"13px",fontWeight:800,color:C.n700,marginBottom:"12px"}}>شكل الاستجابة القياسي</h4>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"12px"}}>
                <div>
                  <div style={{fontSize:"11px",fontWeight:700,color:C.green,marginBottom:"6px"}}>✓ نجاح (2xx)</div>
                  <div style={{background:"#0F172A",borderRadius:"8px",padding:"12px 14px",fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:"#94A3B8",lineHeight:1.8}}>
                    <div style={{color:"#64748B"}}>{"{"}</div>
                    <div>&nbsp;&nbsp;<span style={{color:"#7DD3FC"}}>"data"</span>: <span style={{color:"#86EFAC"}}>{"[...] or {...}"}</span>,</div>
                    <div>&nbsp;&nbsp;<span style={{color:"#7DD3FC"}}>"count"</span>: <span style={{color:"#FCA5A5"}}>number</span></div>
                    <div style={{color:"#64748B"}}>{"}"}</div>
                  </div>
                </div>
                <div>
                  <div style={{fontSize:"11px",fontWeight:700,color:C.red,marginBottom:"6px"}}>✗ خطأ (4xx / 5xx)</div>
                  <div style={{background:"#0F172A",borderRadius:"8px",padding:"12px 14px",fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:"#94A3B8",lineHeight:1.8}}>
                    <div style={{color:"#64748B"}}>{"{"}</div>
                    <div>&nbsp;&nbsp;<span style={{color:"#7DD3FC"}}>"message"</span>: <span style={{color:"#86EFAC"}}>"error description"</span>,</div>
                    <div>&nbsp;&nbsp;<span style={{color:"#7DD3FC"}}>"code"</span>: <span style={{color:"#86EFAC"}}>"PGRST116"</span></div>
                    <div style={{color:"#64748B"}}>{"}"}</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Supabase-specific headers */}
            <div style={{background:C.p50,border:`1px solid ${C.p100}`,borderRadius:"14px",padding:"18px 20px"}}>
              <h4 style={{fontSize:"13px",fontWeight:800,color:C.p700,marginBottom:"12px"}}>PostgREST — Headers مهمة</h4>
              <div style={{display:"flex",flexDirection:"column",gap:"8px"}}>
                {[
                  {h:"Prefer: return=representation",d:"أرجع الـ object الكامل بعد INSERT/UPDATE (بدلاً من {})"},
                  {h:"Prefer: count=exact",           d:"أرجع العدد الكامل في header X-Total-Count (للـ pagination)"},
                  {h:"Range: 0-19",                   d:"pagination — أول 20 عنصر (بديل limit/offset)"},
                  {h:"Accept: application/geo+json",  d:"للـ PostGIS — إرجاع نتائج كـ GeoJSON"},
                ].map(item=>(
                  <div key={item.h} style={{display:"flex",gap:"12px",alignItems:"flex-start",background:C.n0,borderRadius:"8px",padding:"9px 12px"}}>
                    <code style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"11px",color:C.p600,fontWeight:600,flexShrink:0}}>{item.h}</code>
                    <span style={{fontSize:"12px",color:C.n600}}>{item.d}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
