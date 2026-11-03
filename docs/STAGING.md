# بيئة التجربة (staging)

مشروع Supabase اسمه `wasla_app` (`bizikadaucsyevdoagmm`)، ومعاه نسخة Android اسمها «وصلة تجريبي». مفيش فيه بيانات حقيقية. ده **مش** الإنتاج.

## الدخول
أرقام اختبار ثابتة، ومفيش SMS بيتبعت:

| الرقم (اكتبه في التطبيق) | الكود |
|---|---|
| 01000000101 | 123456 |
| 01000000102 | 123456 |
| 01000000103 | 123456 |
| 01000000104 | 123456 |
| 01000000105 | 123456 |

أي رقم تاني بيطلع رسالة «خدمة الرسائل غير متاحة حالياً»، لأن مفيش مزوّد SMS على البيئة دي. الأرقام دي متعرّفة في `supabase/config.toml` تحت `[remotes.staging]` بس، والإنتاج مابياخدهاش.

## اللي مش شغال على البيئة دي، وبيحصل إيه
| الخدمة | السبب | اللي بيحصل |
|---|---|---|
| مراجعة الإعلانات الآلية (Anthropic) | مفيش مفتاح | الإعلان بيروح للمراجعة اليدوية (`unreviewed`)، ويتقبل من لوحة الأدمن |
| الدفع (Paymob) | مفيش مفاتيح | رسالة «الدفع الإلكتروني مش متاح في النسخة دي حالياً.» |
| الإشعارات (FCM) | النسخة التجريبية مالهاش تطبيق Firebase | التطبيق شغال من غير push، والإشعارات بتظهر في مركز الإشعارات جوه التطبيق |
| الخرائط | مفيش مفتاح | زرار الخريطة في البحث، وتحديد المكان على الخريطة في النشر، مستخبيين |
| ضغط الصور (Image Transformations) | محتاجة خطة Pro | الصور بتتعرض بحجمها الأصلي (`IMAGE_TRANSFORMS=false`) |

## تثبيت الـ APK على موبايل Android
1. انقل `app-staging-release.apk` للموبايل.
2. افتحه من مدير الملفات. أول مرة الموبايل هيطلب «السماح بالتثبيت من المصدر ده»، وافق للتطبيق اللي فتحت منه الملف.
3. اضغط «تثبيت». لو Play Protect ظهر، اختار «تثبيت على أي حال»، لأن التوقيع تجريبي ومش من المتجر.
4. افتح «وصلة تجريبي» وادخل برقم من الجدول.

النسخة التجريبية اسمها `com.ahmedmaamoun.wasla.staging`، فبتتثبت جنب أي نسخة تانية من غير ما تمسحها. والتحديثات الجاية هتتثبت فوقها عادي، طالما اتمضت بنفس المفتاح.

## إعادة البناء
مفتاح التوقيع التجريبي موجود في `C:\Users\Maamoun\.wasla-staging\` (برّه الريبو، ومعاه `key.properties`). ماتمسحوش، وإلا التحديثات الجاية مش هتتثبت فوق النسخة الحالية.

```bash
cd frontend/mobile/wasla
WASLA_KEY_PROPERTIES=C:/Users/Maamoun/.wasla-staging/key.properties flutter build apk --release --flavor staging --dart-define=SUPABASE_URL=https://bizikadaucsyevdoagmm.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key> --dart-define=IMAGE_TRANSFORMS=false
```

الـ anon key بتجيبه من `npx -y supabase@2.120.0 projects api-keys --project-ref bizikadaucsyevdoagmm`. ولو عايز الخرائط، ضيف `--dart-define=MAPS_API_KEY=<key>`.

## البيانات التجريبية
- **الإضافة:** `npx -y supabase@2.120.0 db query --linked -f scripts/data/staging_seed.sql`. بتضيف حوالي 360 مستخدم و3000 إعلان، ومعاهم تواصل وتقييمات وبلاغات، وكله متعلّم `is_seed`.
- **المسح:** `npx -y supabase@2.120.0 db query --linked "select public.delete_seed_data();"`. بيمسح بيانات الـ seed بس.
- **الإعلانات بتتوزع على الـ 29 مدينة الموجودة بس** (القاهرة والجيزة والإسكندرية)، لحد ما migration المدن تتعمل بعد تأكيدك.
- **فيه حالات مزروعة عن قصد**، عشان `docs/ALGORITHMS.md` يلاقيها:
  - 12 حساب «مزرعة» بينزّلوا نفس الإعلان بسعر لقطة.
  - حوالي 2% أسعار فيها صفر زيادة أو ناقص.
  - 5 بائعين ليهم تقييمات 5 نجوم من حسابات معملتش أي حاجة تانية.

## اختبار الرحلة على المحاكي
```bash
flutter test integration_test/post_ad_journey_test.dart -d <emulator> --flavor staging --dart-define=SUPABASE_URL=https://bizikadaucsyevdoagmm.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key> --dart-define=IMAGE_TRANSFORMS=false
```
بيسجّل دخول بـ 01000000101، وينشر إعلان، ويتأكد إنه `pending` بصورتين، وبعدين يمسحه هو وصوره.
