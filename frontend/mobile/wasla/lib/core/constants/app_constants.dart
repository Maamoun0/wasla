/// ثوابت التطبيق

class AppStrings {
  AppStrings._();

  // App
  static const String appName     = 'وصلة';
  static const String appTagline  = 'منصة الإعلانات المبوّبة في مصر';

  // Auth
  static const String welcome       = 'أهلاً في وصلة';
  static const String enterPhone    = 'أدخل رقم هاتفك';
  static const String phoneHint     = '01xxxxxxxxx';
  static const String sendOtp       = 'أرسل رمز التحقق';
  static const String verifyOtp     = 'أدخل رمز التحقق';
  static const String otpSentTo     = 'تم إرسال رمز التحقق إلى';
  static const String resendOtp     = 'إعادة إرسال';
  static const String orContinueWith= 'أو تابع بـ';
  static const String browseAsGuest = 'تصفح بدون تسجيل';
  static const String continueWith  = 'تابع';
  static const String confirm       = 'تأكيد';

  // Onboarding
  static const List<Map<String, String>> onboardingSlides = [
    {
      'title': 'ابحث بسهولة',
      'desc': 'آلاف الإعلانات في مدينتك — خدمات، وظائف، عقارات، سيارات وأكثر',
      'animation': 'assets/animations/search.json',
    },
    {
      'title': 'انشر مجاناً',
      'desc': 'أضف إعلانك خلال دقيقتين ويصل لآلاف الباحثين في منطقتك',
      'animation': 'assets/animations/post.json',
    },
    {
      'title': 'تواصل مباشر',
      'desc': 'بدون وسيط — اتصل أو واتساب مع المعلن مباشرة بضغطة واحدة',
      'animation': 'assets/animations/connect.json',
    },
  ];

  // Navigation
  static const String home         = 'الرئيسية';
  static const String explore      = 'اكتشف';
  static const String post         = 'أضف';
  static const String saved        = 'المحفوظة';
  static const String profile      = 'حسابي';

  // Ads
  static const String offering     = 'معروض';
  static const String seeking      = 'مطلوب';
  static const String featured     = 'مميز';
  static const String urgent       = 'عاجل';
  static const String verified     = 'موثّق';
  static const String free         = 'مجاناً';
  static const String negotiable   = 'قابل للتفاوض';
  static const String perHour      = 'في الساعة';
  static const String perMonth     = 'شهرياً';
  static const String egp          = 'ج.م';
  static const String contact      = 'تواصل';
  static const String call         = 'اتصال';
  static const String whatsapp     = 'واتساب';
  static const String save         = 'حفظ';
  static const String report       = 'بلّغ';
  static const String viewAll      = 'عرض الكل';
  static const String noAdsFound   = 'لا توجد إعلانات';
  static const String noAdsDesc    = 'كن أول من ينشر في هذه المنطقة!';

  // Post Ad Steps
  static const String selectCategory = 'اختر القسم';
  static const String adDetails      = 'تفاصيل الإعلان';
  static const String addPhotos      = 'أضف الصور';
  static const String locationPrice  = 'الموقع والسعر';
  static const String preview        = 'معاينة';
  static const String publish        = 'انشر الإعلان';
  static const String adPending      = 'إعلانك قيد المراجعة!';
  static const String adPendingDesc  = 'ستُخطَر خلال ساعة عند الموافقة';

  // Errors
  static const String errorGeneral    = 'حدث خطأ. حاول مرة أخرى';
  static const String errorNetwork    = 'تحقق من الاتصال بالإنترنت';
  static const String errorInvalidPhone = 'رقم هاتف غير صحيح';
  static const String errorInvalidOtp   = 'رمز التحقق غير صحيح';
  static const String errorRequired     = 'هذا الحقل مطلوب';
}

class AppSizes {
  AppSizes._();

  // Spacing
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;

  // Border Radius
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 20;
  static const double radiusFull= 100;

  // Card
  static const double cardPadding = 16;
  static const double cardRadius  = 14;

  // Bottom Nav
  static const double bottomNavHeight = 70;

  // Ad Card
  static const double adCardImageHeight = 160;
  static const double adCardRadius      = 14;
}

class AppDurations {
  AppDurations._();

  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration normal  = Duration(milliseconds: 300);
  static const Duration slow    = Duration(milliseconds: 500);
  static const Duration splash  = Duration(seconds: 2);
  static const Duration otpResend = Duration(seconds: 60);
}

class AppAssets {
  AppAssets._();

  // Animations
  static const String splashAnim   = 'assets/animations/splash.json';
  static const String searchAnim   = 'assets/animations/search.json';
  static const String postAnim     = 'assets/animations/post.json';
  static const String connectAnim  = 'assets/animations/connect.json';
  static const String successAnim  = 'assets/animations/success.json';
  static const String emptyAnim    = 'assets/animations/empty.json';
  static const String loadingAnim  = 'assets/animations/loading.json';

  // Images
  static const String logo         = 'assets/images/logo.png';
  static const String placeholder  = 'assets/images/placeholder.png';
  static const String avatar       = 'assets/images/default_avatar.png';
}

class AppConfig {
  AppConfig._();

  static const String supabaseUrl     = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String mapsApiKey      = String.fromEnvironment('GOOGLE_MAPS_KEY');
  static const String paymobApiKey    = String.fromEnvironment('PAYMOB_API_KEY');
  static const String defaultCountry  = 'مصر';
  static const String defaultCurrency = 'ج.م';
  static const int    defaultAdExpiry = 30; // days
  static const int    maxPhotosPerAd  = 8;
  static const int    maxTitleChars   = 120;
  static const String egyptPhoneCode  = '+20';
}
