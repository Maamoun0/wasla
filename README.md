# وصلة (Wasla) — Flutter App

> منصة الإعلانات المبوّبة في مصر

---

## 📋 المتطلبات

| الأداة | الإصدار |
|--------|---------|
| Flutter | >= 3.3.0 |
| Dart | >= 3.3.0 |
| Supabase | Project مُنشأ |
| Android Studio / VS Code | أحدث إصدار |

---

## 🚀 خطوات التشغيل

### 1. إنشاء مشروع Supabase

1. افتح [supabase.com](https://supabase.com) وأنشئ مشروعاً جديداً
2. انتقل إلى **SQL Editor**
3. الصق محتوى ملف `wasla-schema.sql` كاملاً
4. اضغط **Run** → قاعدة البيانات جاهزة ✅

### 2. إعداد المتغيرات

أنشئ ملف `.env` في جذر المشروع:

```env
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
GOOGLE_MAPS_KEY=AIzaSy...
PAYMOB_API_KEY=...
```

### 3. تثبيت الحزم

```bash
flutter pub get
```

### 4. إعداد Google Maps

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="${GOOGLE_MAPS_KEY}"/>
```

**iOS** (`ios/Runner/AppDelegate.swift`):
```swift
GMSServices.provideAPIKey("YOUR_KEY")
```

### 5. إعداد Supabase Storage Buckets

في Supabase Dashboard → Storage → New Bucket:
- `ads` → Public ✅
- `avatars` → Public ✅
- `documents` → Private 🔒

### 6. تشغيل التطبيق

```bash
# Android
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# iOS
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

---

## 📁 هيكل المشروع

```
lib/
├── main.dart                          # نقطة البداية
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # ألوان وصلة
│   │   └── app_constants.dart         # ثوابت + strings
│   ├── theme/
│   │   └── app_theme.dart             # Material 3 Theme
│   └── router/
│       └── app_router.dart            # Go Router
├── features/
│   ├── auth/                          # المصادقة
│   │   ├── providers/auth_provider.dart
│   │   └── screens/
│   │       ├── splash_screen.dart
│   │       ├── onboarding_screen.dart
│   │       ├── auth_screen.dart       ✅ كامل
│   │       ├── otp_screen.dart        ✅ كامل
│   │       └── profile_setup_screen.dart
│   ├── home/
│   │   └── screens/home_screen.dart   ✅ كامل
│   ├── explore/
│   │   └── screens/explore_screen.dart ✅ كامل
│   ├── ads/
│   │   └── screens/
│   │       ├── ad_detail_screen.dart  ✅ كامل
│   │       └── seller_profile_screen.dart
│   ├── post_ad/
│   │   └── screens/
│   │       ├── select_category_screen.dart ✅ كامل
│   │       ├── ad_form_screen.dart
│   │       ├── add_photos_screen.dart
│   │       ├── location_price_screen.dart
│   │       ├── ad_preview_screen.dart
│   │       └── ad_success_screen.dart
│   ├── saved/
│   │   └── screens/saved_screen.dart  ✅ كامل
│   ├── profile/
│   │   └── screens/
│   │       ├── profile_screen.dart    ✅ كامل
│   │       ├── my_ads_screen.dart     ✅ كامل
│   │       ├── boost_ad_screen.dart
│   │       └── ...
│   └── notifications/
│       └── screens/notifications_screen.dart ✅ كامل
├── shared/
│   ├── widgets/
│   │   ├── wasla_logo.dart            ✅ Logo + AdCard + Buttons
│   │   └── bottom_nav_shell.dart      ✅ كامل
│   └── providers/
│       └── ads_provider.dart          ✅ كامل
└── models/
```

---

## 🔑 التقنيات المستخدمة

| التقنية | الاستخدام |
|---------|-----------|
| `supabase_flutter` | DB + Auth + Storage + Realtime |
| `flutter_riverpod` | State Management |
| `go_router` | Navigation |
| `cached_network_image` | عرض الصور |
| `image_picker` | رفع الصور |
| `pin_code_fields` | إدخال OTP |
| `url_launcher` | تشغيل الاتصالات |
| `timeago` | عرض الوقت النسبي |
| `shimmer` | Loading placeholders |
| `lottie` | Animations |
| `google_maps_flutter` | الخريطة |

---

## 🎨 Brand Colors

```dart
Primary:  #0D7A84  (الفيروز المصري)
Accent:   #E89510  (الذهب المصري)
BG:       #F9F7F3  (رمال دافئة)
```

---

## 📞 للدعم

GitHub: [github.com/Maamoun0](https://github.com/Maamoun0)
