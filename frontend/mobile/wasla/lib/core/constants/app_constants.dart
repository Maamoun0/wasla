import 'package:easy_localization/easy_localization.dart';
/// ثوابت التطبيق

class AppStrings {
  AppStrings._();

  // App
  static String get appName => 'appName'.tr();
  static String get appTagline => 'appTagline'.tr();

  // Auth
  static String get welcome => 'welcome'.tr();
  static String get enterPhone => 'enterPhone'.tr();
  static String get phoneHint => 'phoneHint'.tr();
  static String get sendOtp => 'sendOtp'.tr();
  static String get verifyOtp => 'verifyOtp'.tr();
  static String get otpSentTo => 'otpSentTo'.tr();
  static String get resendOtp => 'resendOtp'.tr();
  static String get orContinueWith => 'orContinueWith'.tr();
  static String get browseAsGuest => 'browseAsGuest'.tr();
  static String get continueWith => 'continueWith'.tr();
  static String get confirm => 'confirm'.tr();

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
  static String get home => 'home'.tr();
  static String get explore => 'explore'.tr();
  static String get post => 'post'.tr();
  static String get saved => 'saved'.tr();
  static String get profile => 'profile'.tr();

  // Ads
  static String get offering => 'offering'.tr();
  static String get seeking => 'seeking'.tr();
  static String get featured => 'featured'.tr();
  static String get urgent => 'urgent'.tr();
  static String get verified => 'verified'.tr();
  static String get free => 'free'.tr();
  static String get negotiable => 'negotiable'.tr();
  static String get perHour => 'perHour'.tr();
  static String get perMonth => 'perMonth'.tr();
  static String get egp => 'egp'.tr();
  static String get contact => 'contact'.tr();
  static String get call => 'call'.tr();
  static String get whatsapp => 'whatsapp'.tr();
  static String get save => 'save'.tr();
  static String get report => 'report'.tr();
  static String get viewAll => 'viewAll'.tr();
  static String get noAdsFound => 'noAdsFound'.tr();
  static String get noAdsDesc => 'noAdsDesc'.tr();

  // Post Ad Steps
  static String get selectCategory => 'selectCategory'.tr();
  static String get adDetails => 'adDetails'.tr();
  static String get addPhotos => 'addPhotos'.tr();
  static String get locationPrice => 'locationPrice'.tr();
  static String get preview => 'preview'.tr();
  static String get publish => 'publish'.tr();
  static String get adPending => 'adPending'.tr();
  static String get adPendingDesc => 'adPendingDesc'.tr();

  // Errors
  static String get errorGeneral => 'errorGeneral'.tr();
  static String get errorNetwork => 'errorNetwork'.tr();
  static String get errorInvalidPhone => 'errorInvalidPhone'.tr();
  static String get errorInvalidOtp => 'errorInvalidOtp'.tr();
  static String get errorRequired => 'errorRequired'.tr();
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
  static const String splashAnim = 'assets/animations/splash.json';
  static const String searchAnim = 'assets/animations/search.json';
  static const String postAnim = 'assets/animations/post.json';
  static const String connectAnim = 'assets/animations/connect.json';
  static const String successAnim = 'assets/animations/success.json';
  static const String emptyAnim = 'assets/animations/empty.json';
  static const String loadingAnim = 'assets/animations/loading.json';

  // Images
  static const String logo = 'assets/images/logo.png';
  static const String placeholder = 'assets/images/placeholder.png';
  static const String avatar = 'assets/images/default_avatar.png';
}

class AppConfig {
  AppConfig._();

  static const String supabaseUrl     = String.fromEnvironment('SUPABASE_URL',     defaultValue: 'https://bizikadaucsyevdoagmm.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpemlrYWRhdWNzeWV2ZG9hZ21tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MDUwNTUsImV4cCI6MjA5OTE4MTA1NX0.f-0cxoeh_h9r3PkJ1D_C0q7-JTFXg50zzrmY6enZG3Q');
  /// Google Maps key (`--dart-define=MAPS_API_KEY=…`; Gradle reads the same
  /// define). Without it the maps are hidden: the SDK refuses to run keyless.
  static const String mapsApiKey      = String.fromEnvironment('MAPS_API_KEY',      defaultValue: '');
  static bool get mapsEnabled => mapsApiKey.isNotEmpty;
  /// Resized photos through Storage's render endpoint (a Pro-plan feature).
  /// `--dart-define=IMAGE_TRANSFORMS=false` serves the original files instead.
  static const bool imageTransforms = bool.fromEnvironment('IMAGE_TRANSFORMS', defaultValue: true);
  static const String paymobApiKey    = String.fromEnvironment('PAYMOB_API_KEY', defaultValue: '');
  static String get defaultCountry => 'defaultCountry'.tr();
  static String get defaultCurrency => 'defaultCurrency'.tr();
  static const int    defaultAdExpiry = 30; // days
  static const int    maxPhotosPerAd  = 8;
  static const int    maxTitleChars   = 120;
  static String get egyptPhoneCode => 'egyptPhoneCode'.tr();
}
