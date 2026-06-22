# 🚗 📱 منصة وصلة (Wasla) - Classifieds & Smart Map-Based Ads Platform

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=flat&logo=supabase&logoColor=white)](https://supabase.com)
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**منصة "وصلة" (Wasla)** هي منصة إعلانات مبوبة مبتكرة ومصممة خصيصاً لتلبية احتياجات السوق المصري بشكل ذكي وآمن. تركز المنصة على حل مشاكل الثقة والوصول الجغرافي وجودة التواصل من خلال دمج تقنيات التوثيق الأمني الرقمي (KYC)، والخرائط الحية لتحديد موقع الإعلانات بدقة، مع الحفاظ على تجربة مستخدم سريعة وعصرية.

---

## 🌍 Table of Contents / جدول المحتويات
1. [Key Features / الميزات الرئيسية](#-key-features--الميزات-الرئيسية)
2. [Architecture & Tech Stack / بنية النظام والتقنيات](#-architecture--tech-stack--بنية-النظام-والتقنيات)
3. [Project Directory Structure / هيكل مجلدات المشروع](#-project-directory-structure--هيكل-مجلدات-المشروع)
4. [Getting Started / خطوات التشغيل والتهيئة](#-getting-started--خطوات-التشغيل-والتهيئة)
5. [Database & Backend Setup / إعداد قاعدة البيانات والخدمات الخلفية](#-database--backend-setup--إعداد-قاعدة-البيانات-والخدمات-الخلفية)
6. [Security & Verification (KYC) / الأمان ونظام التحقق](#-security--verification-kyc--الأمان-ونظام-التحقق)
7. [Contributing & Version Control / المساهمة وإدارة النسخ](#-contributing--version-control--المساهمة-وإدارة-النسخ)

---

## 🌟 Key Features / الميزات الرئيسية

### 🛡️ Trust & Security / الأمان والموثوقية
* **Verified Profiles (KYC):** نظام تحقق اختياري بالرقم القومي من خلال فحص الوجه وبطاقة الهوية لمنع الإعلانات الوهمية وإضفاء شارة "✓ موثق".
* **Trust Badges & User Ratings:** نظام تقييم متبادل يعتمد على الشفافية والتجارب الحقيقية للمستخدمين.

### 📍 Smart Geolocation / التموضع الجغرافي الذكي
* **Proximity Searches:** عرض الإعلانات الأقرب جغرافياً للمستخدم بشكل تلقائي اعتماداً على نظام تحديد المواقع (GPS).
* **Live Map Views:** تصفح الإعلانات بشكل تفاعلي على الخرائط مع تجميع الإعلانات القريبة (Clustering) لتسهيل الاستكشاف.

### ⚡ Professional User Experience / تجربة نشر إعلانات احترافية
* **Dynamic Ad Wizard:** فورم نشر ديناميكي يتكيف حسب القسم المختار (مثال: حقول العداد وسنة الصنع للسيارات، أو المساحة وعدد الغرف للعقارات).
* **Robust Media Manager:** إمكانية رفع وتعديل وترتيب حتى 8 صور عالية الدقة لكل إعلان مع معالجة الصور وضغطها محلياً وسحابياً.

---

## 🛠️ Architecture & Tech Stack / بنية النظام والتقنيات

### 📱 Frontend (Mobile App)
* **Framework:** Flutter (>= 3.3.0) & Dart (>= 3.3.0)
* **State Management:** Riverpod 3.0 (with automatic code generation and clean state flow).
* **Navigation:** GoRouter (implementing shell routing, guards, and smooth transitions).
* **Local Storage & Cache:** SharedPreferences & cached_network_image for offline media persistence.

### 🔌 Backend & Serverless
* **Database & Auth:** Supabase (PostgreSQL with custom triggers, Row Level Security (RLS), and custom indexes).
* **Serverless Functions:** Supabase Edge Functions (Deno TypeScript) for heavy and secure logic (e.g. OTP validation, KYC document handling, payment gateway integration).
* **Third-Party APIs:**
  * **Google Maps API:** Geocoding and interactive maps.
  * **Paymob:** Egyptian Payment gateway for credit card, mobile wallets, and Fawry.

---

## 📁 Project Directory Structure / هيكل مجلدات المشروع

```
wasla/
├── .github/                   # GitHub Actions for CI/CD pipeline
├── backend/
│   └── database/              # PostgreSQL schema migration, functions, and seed data
│       ├── wasla-schema.sql   # Primary core database schema
│       └── *.sql              # Schema updates, triggers, and query extensions
├── docs/                      # Architectural specs, QA testing plans, SRS, and deployment guides
├── frontend/
│   └── mobile/
│       └── wasla/             # Flutter mobile application
│           ├── lib/
│           │   ├── core/      # App routing, themes, and common utility validators
│           │   ├── features/  # Feature-driven modules (Auth, Ads, Post Ad, Profile)
│           │   └── shared/    # Shared global widgets (e.g. Trust Badge, Bottom Navigation Shell)
│           └── test/          # Comprehensive widget and unit tests
└── supabase/
    └── functions/             # Serverless edge functions (KYC submission, OTP, Ad creation)
```

---

## 🚀 Getting Started / خطوات التشغيل والتهيئة

### 1. Prerequisites / المتطلبات الأساسية
* Flutter SDK (>= 3.3.0)
* Dart SDK (>= 3.3.0)
* Supabase CLI (Optional, for local development)
* Android Studio / Xcode

### 2. Environment Configuration / إعداد ملف المتغيرات
Create a `.env` file inside `frontend/mobile/wasla/` with the following configuration:
```env
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
GOOGLE_MAPS_KEY=AIzaSy...
PAYMOB_API_KEY=...
```

### 3. Install Dependencies / تثبيت الحزم
Navigate to the flutter workspace and install packages:
```bash
cd frontend/mobile/wasla
flutter pub get
```

---

## 🗄️ Database & Backend Setup / إعداد قاعدة البيانات والخدمات الخلفية

1. Create a new project on [Supabase Console](https://supabase.com).
2. Open the **SQL Editor** in the dashboard.
3. Execute `backend/database/wasla-schema.sql` to initialize tables, relationships, triggers, and security policies.
4. Execute migration updates from `backend/database/` sequentially for the latest system features.
5. Setup the storage buckets in Supabase Storage:
   * `ads` (Public) - For ad photos.
   * `avatars` (Public) - For user profile pictures.
   * `id-documents` (Private) - For sensitive identity card photos (KYC).

---

## 🛡️ Security & Verification (KYC) / الأمان ونظام التحقق

Wasla treats user data with extreme sensitivity:
* **Private Buckets:** KYC images are stored in a private bucket (`id-documents`) restricted via Supabase RLS.
* **Secured Edge Functions:** The KYC document verification is processed through the serverless function `submit-kyc-request` with role validation.
* **Row-Level Security (RLS):** Enabled on all transaction, messages, and profile tables to guarantee data isolation.

---

## 📈 Contributing & Version Control / المساهمة وإدارة النسخ

* We adopt the **Git Flow** strategy:
  * `main` is reserved strictly for production-ready releases.
  * `develop` is the primary integration branch for active development.
  * Feature branches are branched from `develop` and merged back via pull requests.
* All commits are structured under conventional commit guidelines (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`).

---
Developed by **Ahmed Maamoun** - Egypt
[GitHub Profile](https://github.com/Maamoun0) | [Email](mailto:ahmed.maamoun.dev@gmail.com)
