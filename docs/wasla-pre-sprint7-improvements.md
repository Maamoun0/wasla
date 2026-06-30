# 🔧 وصلة (Wasla) — التعديلات العاجلة قبل السبرنت 7
### 4 تعديلات على كود موجود — بنفس عقد المهمة الذرية المعتاد

> هذه التعديلات على كود بُني بالفعل في السبرنتات 3 و2 و0. كل تعديل مُقيَّد بنطاق ضيق جداً — لا إضافة ميزات جديدة، تحسين فقط.

---

## التعديل 1 — `ai-content-review`: نظام التصفية متعدد الطبقات

### الملف المستهدَف
```
Edge Function: ai-content-review (مبنية في السبرنت 3)
```

### المواصفة الكاملة

**المنطق الحالي (يجب استبداله):**
```
كل إعلان → Claude API مباشرة → ai_risk_level
```

**المنطق الجديد (ثلاث طبقات):**
```
كل إعلان
   ↓
الطبقة 1: RegEx محلي (صفر تكلفة، أقل من 1ms)
   → إذا وُجدت كلمة من قائمة المحظورات → high فوراً، توقف هنا
   ↓ (لو اجتازت)
الطبقة 2: claude-haiku-4-5 (أرخص وأسرع)
   → تصنيف أولي: low / medium / high
   → إذا كان النتيجة low → توقف هنا (الغالبية العظمى من الإعلانات)
   ↓ (لو medium أو high فقط)
الطبقة 3: claude-sonnet-4-6 (أعلى دقة)
   → تأكيد نهائي للحالات المشكوك فيها فقط
   → النتيجة هي ai_risk_level النهائية
```

### قائمة الكلمات المحظورة للطبقة 1 (قابلة للتوسعة لاحقاً)
```javascript
const BANNED_PATTERNS = [
  // أسلحة
  /سلاح|مسدس|بندقية|ذخيرة|متفجر/i,
  // مخدرات
  /مخدر|حشيش|بانجو|كوكايين|هيروين/i,
  // نصب صريح
  /ربح سريع|مليون في أسبوع|استثمار مضمون 100%/i,
  // وثائق مزوّرة
  /شهادة مزور|رخصة مزور|جواز مزور/i,
];
```

### تفاصيل البنية المطلوبة
```typescript
async function reviewContent(title: string, description: string, price: number, category: string) {

  // الطبقة 1: RegEx (محلي، بلا استدعاء خارجي)
  const fullText = `${title} ${description}`;
  for (const pattern of BANNED_PATTERNS) {
    if (pattern.test(fullText)) {
      return {
        ai_risk_level: 'high',
        ai_review_notes: 'محتوى مخالف صريح — كلمات محظورة',
        layer_used: 1
      };
    }
  }

  // الطبقة 2: Haiku (سريع ورخيص)
  const haikusResult = await callClaude('claude-haiku-4-5', buildPrompt(title, description, price, category));
  if (haikusResult.risk_level === 'low') {
    return { ai_risk_level: 'low', ai_review_notes: haikusResult.notes, layer_used: 2 };
  }

  // الطبقة 3: Sonnet (للحالات المشكوك فيها فقط)
  const sonnetResult = await callClaude('claude-sonnet-4-6', buildPrompt(title, description, price, category));
  return { ai_risk_level: sonnetResult.risk_level, ai_review_notes: sonnetResult.notes, layer_used: 3 };
}
```

### ⚠️ نقطة حرجة للوكيل
أضف عمود `layer_used` (integer 1/2/3) لجدول `ads` أو لـ `ai_review_notes` كجزء من النص — هذا البيانات ثمينة لاحقاً لتقييم دقة كل طبقة وتحسينها. لا تحذف هذه المعلومة.

### داخل النطاق
- تعديل Edge Function الموجودة فقط
- إضافة عمود `ai_layer_used` (smallint) على جدول `ads` في Staging

### خارج النطاق
- ⚠️ لا تعديل على `create-ad` أو أي شيء آخر

### معيار القبول
```
☐ إعلان يحتوي كلمة "مسدس" → يُصنَّف high بدون أي استدعاء لـ Claude API
   (يُتحقَّق بمراقبة logs — صفر استدعاءات API للطبقة 1)
☐ إعلان "سباك محترف بالقاهرة سعر مناسب" → يُصنَّف low من الطبقة 2
   (يُتحقَّق من قيمة layer_used = 2 في قاعدة البيانات)
☐ إعلان غامض يحتوي إشارات مشبوهة غير صريحة → يصل للطبقة 3
   (يُتحقَّق من layer_used = 3)
☐ فشل كلا النموذجين (Haiku وSonnet) → الإعلان يُصنَّف medium تلقائياً
   (لا يُوقَف النشر بسبب عطل خارجي)
```

---

## التعديل 2 — Cron Job: تنظيف المعاملات المعلّقة

### الملف المستهدَف
```
قاعدة البيانات Staging — إضافة وظيفة pg_cron جديدة
```

### المواصفة الكاملة

```sql
-- التحقق أن امتداد pg_cron مُفعَّل (Supabase يدعمه افتراضياً)
-- تشغيل هذا على Staging فقط أولاً

SELECT cron.schedule(
  'cleanup-stale-transactions',
  '0 * * * *',  -- كل ساعة بالضبط
  $$
    UPDATE transactions
    SET
      status = 'expired',
      updated_at = now()
    WHERE
      status = 'pending'
      AND created_at < now() - interval '2 hours';
  $$
);

-- التأكد من تسجيل عدد الصفوف المُحدَّثة في كل تشغيل
-- (Supabase يسجّل هذا تلقائياً في cron.job_run_details)
```

### داخل النطاق
- إضافة وظيفة pg_cron واحدة فقط
- التأكد أن جدول `transactions` يملك عمود `updated_at` (موجود بالفعل في الـ Schema الأصلي — تحقق قبل الإضافة)

### خارج النطاق
- ⚠️ لا تعديل على منطق `payment-webhook` أو أي Edge Function

### معيار القبول
```
☐ إدراج معاملة تجريبية بـ created_at قبل 3 ساعات مباشرة في قاعدة البيانات
☐ انتظار دورة الـ Cron التالية (أو تشغيله يدوياً)
☐ المعاملة تتحول إلى expired تلقائياً
☐ فحص cron.job_run_details يُظهر تشغيلاً ناجحاً مع عدد الصفوف المُحدَّثة
```

---

## التعديل 3 — Image Transformation: Thumbnails في بطاقات الإعلانات

### الملفات المستهدَفة
```
Flutter:
- widgets/ad_card.dart (أو ما يعادله — بطاقة الإعلان في Home/Explore)
- screens/home_screen.dart (أي مكان يعرض قائمة إعلانات)
لا تعديل على ad_detail_screen.dart (الصورة الكاملة تبقى كما هي)
```

### المواصفة الكاملة

```dart
// دالة مساعدة واحدة تُضاف في ملف مشترك (مثلاً: lib/utils/image_utils.dart)
class ImageUtils {

  /// للبطاقات والقوائم — جودة مضغوطة
  static String thumbnail(String originalUrl, {int width = 400}) {
    return '$originalUrl?width=$width&quality=70';
  }

  /// لشاشة التفاصيل — الجودة الكاملة
  static String fullQuality(String originalUrl) {
    return originalUrl; // بدون تعديل
  }
}

// الاستخدام في ad_card.dart:
CachedNetworkImage(
  imageUrl: ImageUtils.thumbnail(ad.coverImageUrl),
  // ... باقي الخصائص
)

// الاستخدام في ad_detail_screen.dart (لا تعديل — يبقى كما هو):
CachedNetworkImage(
  imageUrl: ImageUtils.fullQuality(ad.coverImageUrl),
)
```

### ⚠️ شرط مسبق للوكيل
تأكد أن Supabase Image Transformation مُفعَّل على الـ bucket الخاص بصور الإعلانات (ليس bucket الهوية `id-documents`). يُتحقَّق من لوحة Supabase → Storage → Settings.

### داخل النطاق
- إضافة ملف `image_utils.dart` واحد
- تعديل كل مكان يعرض صور إعلانات في القوائم/البطاقات لاستخدام `thumbnail()`
- Ad Detail Screen تبقى بدون تعديل

### خارج النطاق
- ⚠️ bucket `id-documents` لا يُلمَس إطلاقاً
- ⚠️ لا تعديل على منطق رفع الصور من السبرنت 2

### معيار القبول
```
☐ فتح شاشة Home أو Explore ومراقبة Network requests →
   روابط الصور في القائمة تحتوي ?width=400&quality=70
☐ فتح Ad Detail لنفس الإعلان → رابط الصورة بدون أي parameters إضافية
☐ فرق مرئي في سرعة تحميل القائمة (مقارنة بسيطة قبل وبعد)
```

---

## التعديل 4 — Indices: فهارس الأعمدة الحرجة

### الملف المستهدَف
```
قاعدة البيانات Staging — SQL مباشر
```

### المواصفة الكاملة

```sql
-- خطوة 1: تحقق أولاً من الموجود (لا تُنشئ مكررات)
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE tablename IN ('ads', 'transactions', 'users', 'reviews')
ORDER BY tablename, indexname;

-- خطوة 2: بعد مراجعة الناتج، أضف فقط الغائبة:

-- لوحة الإدارة (الأهم)
CREATE INDEX IF NOT EXISTS idx_ads_status_created
  ON ads (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ads_ai_risk_status
  ON ads (ai_risk_level, status)
  WHERE status = 'pending';  -- Partial Index — أكثر كفاءة

-- جدول المعاملات
CREATE INDEX IF NOT EXISTS idx_transactions_status_created
  ON transactions (status, created_at DESC);

-- جدول المستخدمين (للبحث في لوحة الإدارة)
CREATE INDEX IF NOT EXISTS idx_users_deleted_at
  ON users (deleted_at)
  WHERE deleted_at IS NULL;  -- Partial Index للحسابات النشطة فقط
```

### داخل النطاق
- SQL فقط، صفر تعديل على كود Flutter أو Edge Functions

### خارج النطاق
- ⚠️ لا تعديل على أي Index موجود بالفعل من wasla-schema.sql الأصلي

### معيار القبول
```
☐ تشغيل استعلام SELECT من القطعة الأولى بعد الإضافة
   يُظهر الـ Indices الجديدة بالاسم الصحيح
☐ استعلام EXPLAIN ANALYZE على
   "SELECT * FROM ads WHERE status='pending' ORDER BY ai_risk_level"
   يُظهر "Index Scan" لا "Seq Scan"
```

---

## 📋 جدول التتبّع الكامل

```
التعديل 1 — ai-content-review (3 طبقات)
  ☐ إعلان بكلمة محظورة → high بلا استدعاء API (تحقق من logs)
  ☐ إعلان طبيعي → low من الطبقة 2 (layer_used = 2 في DB)
  ☐ فشل النموذجين → medium تلقائياً (لا توقف للنشر)

التعديل 2 — Cron Job تنظيف المعاملات
  ☐ معاملة عمرها 3 ساعات تتحول لـ expired تلقائياً
  ☐ cron.job_run_details يُظهر تشغيلاً ناجحاً

التعديل 3 — Image Transformation
  ☐ روابط القائمة تحتوي ?width=400&quality=70
  ☐ رابط التفاصيل بلا parameters (تحقق من Network requests)

التعديل 4 — Indices
  ☐ pg_indexes يُظهر الـ Indices الجديدة
  ☐ EXPLAIN ANALYZE يُظهر Index Scan لا Seq Scan
```

---

## ترتيب التنفيذ المقترح للوكيل

```
أولاً: التعديل 4 (SQL — الأسرع والأأمن، صفر خطر)
ثانياً: التعديل 2 (SQL — Cron Job بسيط)
ثالثاً: التعديل 3 (Flutter — تعديل بسيط معزول)
رابعاً: التعديل 1 (Edge Function — الأكثر تعقيداً، بعد استقرار البقية)
```

---

## ✅ بعد اكتمال كل التعديلات الأربعة

قبل الانتقال لـ السبرنت 7، شغّل:
```
flutter test        → صفر فشل (التعديل 3 لا يكسر اختبارات قائمة)
flutter analyze     → صفر تحذيرات جديدة
```

بعدها السبرنت 7 (لوحة الإدارة Next.js) جاهز للبدء على أساس محسَّن.
