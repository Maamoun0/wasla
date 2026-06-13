import { useState } from "react";

const C = {
  p50:"#E4F4F6",p100:"#B8E2E6",p200:"#74C4CC",
  p600:"#0D7A84",p700:"#0A606A",p900:"#032B30",
  a50:"#FEF5E4",a500:"#E89510",a600:"#C97C0C",
  n0:"#FFFFFF",n50:"#F9F7F3",n100:"#F0EDE7",n200:"#EAE4DA",
  n400:"#B0A89C",n500:"#8A8278",n600:"#6E6459",n700:"#4E473E",n900:"#161210",
  green:"#16A34A",red:"#DC2626",
};

const GC = {
  onboarding:{bg:"#EDE9FE",fg:"#5B21B6",icon:"🚀"},
  home:      {bg:C.p50,    fg:C.p600,   icon:"🏠"},
  explore:   {bg:"#DCFCE7",fg:"#15803D",icon:"🔍"},
  post:      {bg:"#FEE2E2",fg:"#B91C1C",icon:"➕"},
  saved:     {bg:C.a50,    fg:C.a600,   icon:"❤️"},
  profile:   {bg:"#F1F5F9",fg:"#475569",icon:"👤"},
  payment:   {bg:"#FEF3C7",fg:"#D97706",icon:"💳"},
  admin:     {bg:"#F8FAFC",fg:"#334155",icon:"⚙️"},
};

const SCREENS = [
  // ── ONBOARDING ──
  {id:"splash",g:"onboarding",name:"SplashScreen",route:"/",ar:"شاشة البداية",
   purpose:"شعار وصلة لمدة 2 ثانية ثم انتقال تلقائي",
   widgets:["Scaffold","  AnimatedContainer (gradient bg)","  Center","    Column","      WaslaLogoWidget","      SizedBox(h:16)","      FadeTransition","        Text('وصلة', style: Display)"],
   state:["authStateProvider → يحدد الانتقال التالي"],
   apis:[],
   navTo:["→ /home إذا logged in","→ /onboarding إذا جديد"],
  },
  {id:"onboarding",g:"onboarding",name:"OnboardingScreen",route:"/onboarding",ar:"شاشات التعريف",
   purpose:"3 شرائح تشرح: ابحث | انشر | تواصل",
   widgets:["Scaffold","  PageView (3 slides)","    OnboardingSlide(icon, title, desc)","    OnboardingSlide(...)","    OnboardingSlide(...)","  Positioned: PageIndicator","  Positioned: NextButton / SkipButton"],
   state:["pageController (local StatefulWidget)","currentPageProvider"],
   apis:[],
   navTo:["→ /auth"],
  },
  {id:"auth",g:"onboarding",name:"AuthScreen",route:"/auth",ar:"تسجيل الدخول / إنشاء حساب",
   purpose:"رقم الهاتف أو Google أو Facebook",
   widgets:["Scaffold","  SafeArea","    Column","      WaslaLogo (small)","      Text('أهلاً في وصلة')","      PhoneInputField (EG +20)","      PrimaryButton('أرسل رمز التحقق')","      DividerWithText('أو')","      SocialLoginRow","        GoogleLoginButton","        FacebookLoginButton","      GuestTextButton('تصفح بدون تسجيل')"],
   state:["phoneController","isLoadingProvider","authErrorProvider"],
   apis:["POST /auth/v1/otp — إرسال OTP","POST /auth/v1/token — Google/Facebook"],
   navTo:["→ /auth/otp (بعد إرسال OTP)","→ /home (تسجيل اجتماعي ناجح)"],
  },
  {id:"otp",g:"onboarding",name:"OtpScreen",route:"/auth/otp",ar:"التحقق برمز OTP",
   purpose:"إدخال كود 6 أرقام مع عداد 60 ثانية",
   widgets:["Scaffold","  AppBar (back arrow)","  Column","    Text('أدخل رمز التحقق')","    Text('+20xxxxxxxxxx', مع زر تغيير)","    OtpInputRow (6 fields)","      OtpDigitField × 6","    CountdownTimer(60s)","    ResendButton (disabled حتى انتهاء العداد)","    PrimaryButton('تأكيد')"],
   state:["otpControllers[6]","timerProvider","canResendProvider"],
   apis:["POST /auth/v1/verify","POST /auth/v1/otp (إعادة إرسال)"],
   navTo:["→ /auth/setup (مستخدم جديد)","→ /home (مستخدم موجود)"],
  },
  {id:"profile_setup",g:"onboarding",name:"ProfileSetupScreen",route:"/auth/setup",ar:"إعداد الملف الشخصي",
   purpose:"الاسم + الصورة + المدينة — خطوة واحدة سريعة",
   widgets:["Scaffold","  Column","    AvatarPicker (Camera / Gallery)","    NameTextField","    CityDropdown","      Searchable cities list","    PrimaryButton('ابدأ الاستخدام')","    SkipTextButton"],
   state:["nameController","selectedCityProvider","avatarFileProvider"],
   apis:["PATCH /rest/v1/users","POST /storage/v1/object/avatars/{uid}"],
   navTo:["→ /home"],
  },

  // ── HOME ──
  {id:"home",g:"home",name:"HomeScreen",route:"/home",ar:"الرئيسية",
   purpose:"Feed رئيسي: بانر + أقسام + مميزة + قريبة",
   widgets:["Scaffold","  CustomScrollView","    SliverAppBar (logo + search + bell)","    SliverToBoxAdapter","      FeaturedBannerSlider","      CategoryGridSection (5 icons)","      SectionHeader('إعلانات مميزة')","      FeaturedAdsHorizontalList","      SectionHeader('قريب منك')","      NearbyAdsGrid","  BottomNavBar"],
   state:["featuredAdsProvider","nearbyAdsProvider","categoriesProvider","userLocationProvider"],
   apis:["GET /rest/v1/ads?is_featured=true","GET /functions/v1/ads-nearby","GET /rest/v1/categories?level=1"],
   navTo:["→ /explore (search tap)","→ /ad/:id (ad tap)","→ /notifications (bell)"],
  },
  {id:"notifications",g:"home",name:"NotificationsScreen",route:"/notifications",ar:"الإشعارات",
   purpose:"قائمة كل الإشعارات مع تمييز المقروء وغير المقروء",
   widgets:["Scaffold","  AppBar('الإشعارات')","  Consumer(notificationsProvider)","    ListView.builder","      NotificationTile","        Icon(type)","        Column(title, body, time)","        UnreadIndicator (dot)","  FAB: MarkAllRead"],
   state:["notificationsProvider","unreadCountProvider"],
   apis:["GET /rest/v1/notifications","PATCH /rest/v1/notifications (mark read)","POST /functions/v1/mark-all-read"],
   navTo:["→ /ad/:id (لإشعارات الإعلانات)"],
  },

  // ── EXPLORE ──
  {id:"explore",g:"explore",name:"ExploreScreen",route:"/explore",ar:"الاكتشاف والبحث",
   purpose:"بحث + أقسام + الشاشة الرئيسية للبحث",
   widgets:["Scaffold","  Column","    SearchBar (with filters icon)","    CategoryTabBar (horizontal scroll)","    Expanded","      Consumer(searchProvider)","        AdResultsWidget","          ToggleRow (List/Grid/Map)","          AdCard × N","    FilterFAB"],
   state:["searchQueryProvider","searchFiltersProvider","searchResultsProvider","viewModeProvider (list/grid/map)"],
   apis:["GET /functions/v1/search-ads","GET /rest/v1/categories"],
   navTo:["→ /explore/results","→ /explore/map","→ /explore/filter","→ /ad/:id"],
  },
  {id:"search_results",g:"explore",name:"SearchResultsScreen",route:"/explore/results",ar:"نتائج البحث",
   purpose:"قائمة / شبكة نتائج مع pagination",
   widgets:["Scaffold","  SliverAppBar (collapsible search)","  Consumer(resultsProvider)","    SliverList / SliverGrid","      AdCard","        AdImage (primary photo)","        AdTitle, Price","        Location, Time","        FeaturedBadge (إذا مميز)","  FilterChipsRow","  ResultsCountText"],
   state:["resultsProvider","paginationProvider","activeFiltersProvider"],
   apis:["GET /functions/v1/search-ads?q=...&filters=..."],
   navTo:["→ /ad/:id","→ /explore/filter"],
  },
  {id:"map_view",g:"explore",name:"MapViewScreen",route:"/explore/map",ar:"عرض الخريطة",
   purpose:"إعلانات على خريطة Google Maps مع clusters",
   widgets:["Scaffold","  Stack","    GoogleMap","      MarkerClusters","      UserLocationMarker","    Positioned(top)","      SearchBar","    DraggableScrollableSheet","      MiniAdCard × visible ads","        (تنزلق من الأسفل)"],
   state:["mapCenterProvider","visibleAdsProvider","selectedAdProvider","zoomLevelProvider"],
   apis:["GET /functions/v1/ads-nearby?lat=...&lng=..."],
   navTo:["→ /ad/:id (marker tap)"],
  },
  {id:"filter_sheet",g:"explore",name:"FilterBottomSheet",route:"(modal)",ar:"شيت الفلاتر",
   purpose:"Bottom sheet للفلاتر: سعر | منطقة | نوع | تاريخ",
   widgets:["DraggableScrollableSheet","  Column","    Handle bar","    FilterSection('نوع الإعلان')","      ChipGroup(معروض/مطلوب)","    FilterSection('نطاق السعر')","      RangeSlider","    FilterSection('المنطقة')","      CityDropdown → DistrictDropdown","    FilterSection('تاريخ النشر')","      DateRangeChips","    Row(ResetButton, ApplyButton)"],
   state:["localFiltersState (StatefulWidget)"],
   apis:[],
   navTo:["← dismiss + apply filters"],
  },
  {id:"ad_detail",g:"explore",name:"AdDetailScreen",route:"/ad/:id",ar:"تفاصيل الإعلان",
   purpose:"كل تفاصيل الإعلان + معلومات المعلن + تواصل",
   widgets:["Scaffold","  CustomScrollView","    SliverAppBar","      PhotoGallery (PageView)","      PhotoCounter (3/8)","    SliverToBoxAdapter","      AdTitle + PriceBadge","      LocationChip + TimestampText","      UrgentBadge (إذا عاجل)","      Divider","      DynamicFieldsGrid (حسب القسم)","      Divider","      DescriptionText (expandable)","      Divider","      SellerCard","        AvatarWidget","        NameText + VerifiedBadge","        TrustScore (stars)","        ViewProfileButton","      RelatedAdsList","  BottomActionBar","    FavoriteButton","    WhatsAppButton","    CallButton"],
   state:["adDetailProvider(id)","isFavoritedProvider","contactLogState"],
   apis:["GET /rest/v1/ads?id=eq.{id}","POST /rest/v1/contact_logs","POST /rest/v1/favorites"],
   navTo:["→ /seller/:id","→ /photos/:id (gallery)"],
  },
  {id:"seller_profile",g:"explore",name:"SellerProfileScreen",route:"/seller/:id",ar:"ملف المعلن",
   purpose:"ملف المعلن العام + كل إعلاناته + تقييماته",
   widgets:["Scaffold","  CustomScrollView","    SliverAppBar","      AvatarWidget (large)","      NameText + VerifiedBadge","      TrustScoreRow","      StatsRow (إعلانات / تقييمات)","    SliverTabBar","      Tab('الإعلانات')","      Tab('التقييمات')","    SliverTabBarView","      AdsList","      ReviewsList","        ReviewCard × N","          StarRating","          Comment","          ReviewResponse (إن وُجدت)"],
   state:["sellerProvider(id)","sellerAdsProvider","sellerReviewsProvider"],
   apis:["GET /rest/v1/users?id=eq.{id}","GET /rest/v1/ads?user_id=eq.{id}","GET /rest/v1/reviews?reviewed_user_id=eq.{id}"],
   navTo:["→ /ad/:id"],
  },
  {id:"photo_viewer",g:"explore",name:"PhotoViewerScreen",route:"/photos/:adId",ar:"معرض الصور",
   purpose:"عرض الصور بشاشة كاملة مع Zoom وسحب",
   widgets:["Scaffold (black bg)","  PhotoViewGallery","    PageView","      ZoomableImage × N","  Overlay","    BackButton","    PhotoCounter (2/5)","    DownloadButton"],
   state:["currentIndexProvider"],
   apis:[],
   navTo:["← back"],
  },

  // ── POST AD ──
  {id:"select_category",g:"post",name:"SelectCategoryScreen",route:"/post/category",ar:"اختيار القسم",
   purpose:"3 مستويات: رئيسي → فرعي → تفصيلي",
   widgets:["Scaffold","  AppBar('نشر إعلان - 1/5')","  LinearProgressIndicator(0.2)","  Column","    Text('اختر قسم إعلانك')","    Consumer(categoriesProvider)","      CategoryGridLevel1","        CategoryCard(icon, name) × 5","    Expanded AnimatedSwitcher","      SubCategoryList (level 2)","      LeafCategoryList (level 3)"],
   state:["selectedCategoryProvider","categoryLevelProvider"],
   apis:["GET /rest/v1/categories","GET /functions/v1/category-tree"],
   navTo:["→ /post/form (بعد اختيار قسم تفصيلي)"],
  },
  {id:"ad_form",g:"post",name:"AdFormScreen",route:"/post/form",ar:"تفاصيل الإعلان",
   purpose:"Form ديناميكي يتغير حسب القسم المختار",
   widgets:["Scaffold","  AppBar('نشر إعلان - 2/5')","  LinearProgressIndicator(0.4)","  Form(key: formKey)","    Column","      AdTypeToggle(معروض / مطلوب)","      TitleField (max 120 حرف)","      DescriptionField (expandable)","      DynamicFields (من category_fields)","        TextFormField","        NumberFormField","        DropdownFormField","        SwitchFormField","      PriceSection","        PriceTypeChips","        PriceField","  BottomButton('التالي →')"],
   state:["postAdDraftProvider","formValidationProvider","dynamicFieldsProvider"],
   apis:["GET /rest/v1/category_fields?category_id=eq.{id}"],
   navTo:["→ /post/photos","← /post/category"],
  },
  {id:"add_photos",g:"post",name:"AddPhotosScreen",route:"/post/photos",ar:"إضافة الصور",
   purpose:"رفع حتى 8 صور مع تحديد الرئيسية وإعادة الترتيب",
   widgets:["Scaffold","  AppBar('نشر إعلان - 3/5')","  LinearProgressIndicator(0.6)","  Column","    Text('أضف صوراً لإعلانك')","    ReorderableGridView","      PhotoTile(image, isPrimary)","        SetPrimaryButton","        DeleteButton","      AddPhotoButton","        CameraOption","        GalleryOption","    PrimaryPhotoHint","  BottomButton('التالي →')"],
   state:["photosListProvider","primaryPhotoIndexProvider","uploadProgressProvider"],
   apis:["POST /storage/v1/object/ads/{adId}/{filename}","POST /rest/v1/ad_media"],
   navTo:["→ /post/location","← /post/form"],
  },
  {id:"location_price",g:"post",name:"LocationPriceScreen",route:"/post/location",ar:"الموقع والسعر",
   purpose:"اختيار المنطقة من خريطة أو قائمة + تحديد السعر",
   widgets:["Scaffold","  AppBar('نشر إعلان - 4/5')","  LinearProgressIndicator(0.8)","  Column","    SectionHeader('الموقع')","    GovernorateDropdown","    CityDropdown","    DistrictDropdown","    MapPreview (optional tap to pinpoint)","    SectionHeader('السعر')","    PriceTypeSegment","    PriceField","    CurrencyLabel(EGP)","    ContactSection","      PhoneSwitch(إظهار/إخفاء رقمي)","      WhatsAppSwitch","  BottomButton('معاينة →')"],
   state:["locationProvider","priceProvider","contactPrefsProvider"],
   apis:["GET /rest/v1/governorates","GET /rest/v1/cities","GET /rest/v1/districts"],
   navTo:["→ /post/preview","← /post/photos"],
  },
  {id:"ad_preview",g:"post",name:"AdPreviewScreen",route:"/post/preview",ar:"معاينة الإعلان",
   purpose:"عرض الإعلان كما سيظهر للمستخدمين قبل النشر",
   widgets:["Scaffold","  AppBar('معاينة - 5/5')","  LinearProgressIndicator(1.0)","  Column","    PreviewBanner('هكذا سيظهر إعلانك')","    AdDetailCard (read-only)","      PhotoGallery","      TitlePriceBadge","      DynamicFields","      LocationChip","      SellerCard (بياناتك)","  BottomRow","    EditButton","    PublishButton (primary)"],
   state:["postAdDraftProvider (read)"],
   apis:[],
   navTo:["→ /post/success (بعد النشر)","← /post/location (تعديل)","POST /rest/v1/ads (على الزر)"],
  },
  {id:"ad_success",g:"post",name:"AdSuccessScreen",route:"/post/success",ar:"تم إرسال الإعلان",
   purpose:"تأكيد الإرسال وتوجيه المستخدم للخطوة التالية",
   widgets:["Scaffold","  Column(mainAxisAlignment: center)","    SuccessAnimation (Lottie)","    Text('إعلانك قيد المراجعة!')","    Text('ستُخطَر خلال ساعة')","    PrimaryButton('عرض إعلاناتي')","    OutlineButton('نشر إعلان آخر')","    TextButton('العودة للرئيسية')"],
   state:[],
   apis:[],
   navTo:["→ /profile/my-ads","→ /post/category","→ /home"],
  },

  // ── SAVED ──
  {id:"saved",g:"saved",name:"SavedScreen",route:"/saved",ar:"المفضلة والـ Watchlist",
   purpose:"تبويبان: إعلانات محفوظة + بحوث محفوظة",
   widgets:["Scaffold","  AppBar('المحفوظة')","  TabBar","    Tab('المفضلة (N)')","    Tab('تنبيهاتي (N)')","  TabBarView","    FavoritesTab","      ListView","        FavoriteAdCard","          AdImage, Title, Price","          NotesChip (إذا كانت هناك ملاحظات)","          DeleteButton","    WatchlistTab","      ListView","        WatchlistCard","          SearchName","          FilterChips","          ToggleActiveSwitch","          DeleteButton"],
   state:["favoritesProvider","watchlistProvider"],
   apis:["GET /rest/v1/favorites","GET /rest/v1/saved_searches"],
   navTo:["→ /ad/:id","→ /saved/watchlist-results/:id"],
  },
  {id:"watchlist_results",g:"saved",name:"WatchlistResultsScreen",route:"/saved/watchlist/:id",ar:"نتائج Watchlist",
   purpose:"الإعلانات الجديدة التي تطابق بحثاً محفوظاً",
   widgets:["Scaffold","  AppBar(watchlist.name)","  Column","    FilterSummaryChips","    Text('N إعلان جديد منذ آخر زيارة')","    ListView","      AdCard × N"],
   state:["watchlistResultsProvider(id)"],
   apis:["GET /functions/v1/search-ads?filters=watchlist.filters"],
   navTo:["→ /ad/:id"],
  },

  // ── PROFILE ──
  {id:"profile",g:"profile",name:"ProfileScreen",route:"/profile",ar:"حسابي",
   purpose:"ملف المستخدم الشخصي مع كل الروابط",
   widgets:["Scaffold","  CustomScrollView","    SliverAppBar","      AvatarWidget","      NameText + VerifiedBadge","      TrustScoreRow","      EditProfileButton","    SliverToBoxAdapter","      StatsRow","        (إعلاناتي / تقييماتي / مشاهداتي)","      ListTile('إعلاناتي')","      ListTile('تقييماتي')","      ListTile('اشتراكي')","      ListTile('التحقق من الهوية')","      Divider","      ListTile('الإعدادات')","      ListTile('تسجيل الخروج', red)","      ListTile('حذف الحساب', red)"],
   state:["currentUserProvider","userStatsProvider"],
   apis:["GET /auth/v1/user","GET /functions/v1/user-stats"],
   navTo:["→ /profile/my-ads","→ /profile/reviews","→ /profile/subscription","→ /profile/verify","→ /settings"],
  },
  {id:"my_ads",g:"profile",name:"MyAdsScreen",route:"/profile/my-ads",ar:"إعلاناتي",
   purpose:"إدارة إعلانات المستخدم: نشطة | معلقة | منتهية | مرفوضة",
   widgets:["Scaffold","  AppBar('إعلاناتي')","  TabBar","    Tab('نشطة')","    Tab('معلقة')","    Tab('منتهية')","    Tab('مرفوضة')","  TabBarView","    MyAdCard × N","      AdImage, Title, Status","      StatsRow(views, contacts, favs)","      ActionMenu","        EditButton","        PauseButton","        BoostButton (golden)","        RefreshButton","        DeleteButton"],
   state:["myAdsProvider(status)"],
   apis:["GET /rest/v1/ads?user_id=eq.{uid}","PATCH /rest/v1/ads (pause/delete)"],
   navTo:["→ /ad/:id/edit","→ /profile/boost/:adId","→ /profile/performance/:adId"],
  },
  {id:"ad_performance",g:"profile",name:"AdPerformanceScreen",route:"/profile/performance/:id",ar:"أداء الإعلان",
   purpose:"تحليلات مشاهدات ومكالمات وحفظ إعلان معين",
   widgets:["Scaffold","  AppBar('أداء الإعلان')","  SingleChildScrollView","    AdMiniCard (header)","    StatsCardsRow","      StatCard('المشاهدات', views_count)","      StatCard('التواصل', contacts_count)","      StatCard('المفضلة', favorites_count)","    SectionHeader('المشاهدات خلال 7 أيام')","    BarChart(views_by_day)","    SectionHeader('طريقة التواصل')","    PieChart(phone/whatsapp/email)","    BoostCTA (إذا لم يكن مُعزَّزاً)"],
   state:["adPerformanceProvider(id)"],
   apis:["GET /functions/v1/ad-performance?ad_id={id}"],
   navTo:["→ /profile/boost/:id"],
  },
  {id:"boost_ad",g:"profile",name:"BoostAdScreen",route:"/profile/boost/:id",ar:"تعزيز الإعلان",
   purpose:"اختيار نوع ومدة الـ Boost ثم الدفع",
   widgets:["Scaffold","  AppBar('تعزيز إعلانك')","  Column","    AdMiniCard","    SectionHeader('اختر نوع التعزيز')","    BoostTypeCards","      BoostTypeCard(⭐ مميز, desc, price)","      BoostTypeCard(🔴 عاجل, desc, price)","      BoostTypeCard(↑ رفع للأعلى, desc, price)","    SectionHeader('مدة التعزيز')","    DurationChips (3/7/14/30 يوم)","    PriceSummaryCard","      BoostType, Duration, Total","    PaymentMethodSection","    ConfirmBoostButton"],
   state:["selectedBoostTypeProvider","selectedDurationProvider","boostPriceProvider"],
   apis:["POST /functions/v1/boost-ad","POST /functions/v1/create-payment"],
   navTo:["→ /payment (Paymob WebView)"],
  },
  {id:"subscription",g:"profile",name:"SubscriptionScreen",route:"/profile/subscription",ar:"خطة الاشتراك",
   purpose:"عرض الخطط والترقية والاشتراك الحالي",
   widgets:["Scaffold","  AppBar('اشتراكي')","  Column","    CurrentPlanCard","      PlanName, ExpiryDate","      UsageBar (إعلانات مستخدمة/متاحة)","    SectionHeader('ترقية خطتك')","    PlanCards(horizontal scroll)","      PlanCard × 4","        PlanName, Price","        FeatureList","        SubscribeButton","    FeaturesComparison Table"],
   state:["currentSubscriptionProvider","plansProvider"],
   apis:["GET /rest/v1/subscription_plans","GET /rest/v1/user_subscriptions","POST /functions/v1/create-payment"],
   navTo:["→ /payment"],
  },
  {id:"verification",g:"profile",name:"VerificationScreen",route:"/profile/verify",ar:"التحقق من الهوية",
   purpose:"مراحل التحقق: هاتف → بريد → رقم قومي",
   widgets:["Scaffold","  AppBar('التحقق من الهوية')","  Column","    VerificationStepCard","      Icon(✓/⏳/✗)","      Text('تحقق الهاتف')","      StatusBadge","    VerificationStepCard","      Text('تحقق البريد')","    VerificationStepCard","      Text('الرقم القومي')","      UploadIDButton","        FrontSideOption","        BackSideOption","    VerificationBenefitsCard","      Text('الفوائد: شارة موثّق، ثقة أعلى...')"],
   state:["verificationStatusProvider"],
   apis:["POST /functions/v1/send-phone-otp","POST /functions/v1/verify-phone","POST /functions/v1/verify-national-id","POST /storage/v1/object/documents/{uid}"],
   navTo:["→ /auth/otp (لتحقق الهاتف)"],
  },
  {id:"reviews",g:"profile",name:"MyReviewsScreen",route:"/profile/reviews",ar:"تقييماتي",
   purpose:"التقييمات الواردة والصادرة مع إمكانية الرد",
   widgets:["Scaffold","  AppBar('تقييماتي')","  TabBar","    Tab('واردة')","    Tab('صادرة')","  TabBarView","    ReviewCard × N","      AvatarWidget","      StarRating","      Comment","      ReplyButton (للواردة فقط)","      ReviewResponseDialog"],
   state:["receivedReviewsProvider","sentReviewsProvider"],
   apis:["GET /rest/v1/reviews?reviewed_user_id=eq.{uid}","POST /rest/v1/review_responses"],
   navTo:[],
  },
  {id:"settings",g:"profile",name:"SettingsScreen",route:"/settings",ar:"الإعدادات",
   purpose:"إعدادات الإشعارات والخصوصية وحذف الحساب",
   widgets:["Scaffold","  AppBar('الإعدادات')","  ListView","    SettingsSection('الإشعارات')","      SwitchTile('إعلانات جديدة')","      SwitchTile('تقييمات جديدة')","      SwitchTile('انتهاء الـ Boost')","    SettingsSection('الخصوصية')","      ListTile('إخفاء رقم هاتفي')","    SettingsSection('الحساب')","      ListTile('تغيير كلمة المرور')","      ListTile('حذف الحساب', red)"],
   state:["notifSettingsProvider"],
   apis:["PATCH /rest/v1/users (settings update)"],
   navTo:[],
  },

  // ── PAYMENT ──
  {id:"payment_webview",g:"payment",name:"PaymentWebViewScreen",route:"/payment",ar:"بوابة الدفع (Paymob)",
   purpose:"WebView يُحمّل iframe Paymob للدفع الآمن",
   widgets:["Scaffold","  AppBar('ادفع بأمان')","    LockIcon","  WebView(paymob_iframe_url)","    onPageFinished → detect success/fail","  LoadingOverlay"],
   state:["paymentUrlProvider","paymentStatusProvider"],
   apis:["POST /functions/v1/create-payment (قبل هذه الشاشة)","POST /functions/v1/payment-webhook (Paymob → سيرفر)"],
   navTo:["→ /payment/success","→ back (فشل)"],
  },
  {id:"payment_success",g:"payment",name:"PaymentSuccessScreen",route:"/payment/success",ar:"تم الدفع بنجاح",
   purpose:"تأكيد الدفع وتفعيل الخدمة",
   widgets:["Scaffold","  Column(center)","    SuccessAnimation (Lottie checkmark)","    Text('تم الدفع بنجاح!')","    ReceiptCard","      ServiceName","      Amount, Method","      TransactionId","    PrimaryButton('العودة للإعلان')"],
   state:[],
   apis:[],
   navTo:["→ /profile/my-ads","→ /home"],
  },

  // ── ADMIN ──
  {id:"moderator_dashboard",g:"admin",name:"ModeratorDashboard",route:"/admin",ar:"لوحة المشرف",
   purpose:"مراجعة الإعلانات المعلقة والبلاغات",
   widgets:["Scaffold","  AppBar('لوحة المشرف')","  Column","    StatsRow","      StatCard('معلّق', N)","      StatCard('بلاغات', N)","    TabBar","      Tab('إعلانات معلقة')","      Tab('بلاغات')","    TabBarView","      PendingAdCard × N","        AdPreview","        ApproveButton (green)","        RejectButton (red) → dialog(reason)","      ReportCard × N","        ReportDetails","        ResolveButton","        DismissButton"],
   state:["pendingAdsProvider","pendingReportsProvider"],
   apis:["GET /functions/v1/admin/pending-ads","POST /functions/v1/admin/approve-ad","POST /functions/v1/admin/reject-ad","GET /functions/v1/admin/reports","POST /functions/v1/admin/resolve-report"],
   navTo:["→ /ad/:id (للمعاينة)"],
  },
];

const PROVIDERS = [
  {name:"authStateProvider",type:"StreamProvider",desc:"حالة المصادقة الحية (logged in / out)"},
  {name:"currentUserProvider",type:"FutureProvider",desc:"ملف المستخدم الحالي من Supabase"},
  {name:"userStatsProvider",type:"FutureProvider",desc:"إحصائيات المستخدم (إعلانات، مشاهدات، تقييمات)"},
  {name:"categoriesProvider",type:"FutureProvider",desc:"شجرة الأقسام الكاملة (cached)"},
  {name:"adsListProvider",type:"StateNotifierProvider",desc:"قائمة الإعلانات مع فلاتر وpagination"},
  {name:"adDetailProvider",type:"FutureProvider.family",desc:"تفاصيل إعلان بعينه بالـ id"},
  {name:"searchProvider",type:"StateNotifierProvider",desc:"حالة البحث (query + filters + results)"},
  {name:"favoritesProvider",type:"StreamProvider",desc:"المفضلة محدّثة في الوقت الفعلي"},
  {name:"watchlistProvider",type:"FutureProvider",desc:"قائمة البحوث المحفوظة"},
  {name:"notificationsProvider",type:"StreamProvider",desc:"الإشعارات محدّثة في الوقت الفعلي"},
  {name:"unreadCountProvider",type:"Provider",desc:"عدد الإشعارات غير المقروءة (للبادج)"},
  {name:"postAdDraftProvider",type:"StateNotifierProvider",desc:"مسودة الإعلان خلال wizard النشر"},
  {name:"currentSubscriptionProvider",type:"FutureProvider",desc:"الاشتراك النشط للمستخدم"},
  {name:"boostStateProvider",type:"StateNotifierProvider",desc:"حالة اختيار الـ Boost"},
  {name:"locationProvider",type:"FutureProvider",desc:"موقع المستخدم الحالي (GPS)"},
  {name:"citiesProvider",type:"FutureProvider",desc:"قائمة المدن (cached بعد أول طلب)"},
];

const ROUTES = [
  {path:"/",                         screen:"SplashScreen",          shell:false},
  {path:"/onboarding",               screen:"OnboardingScreen",       shell:false},
  {path:"/auth",                     screen:"AuthScreen",             shell:false},
  {path:"/auth/otp",                 screen:"OtpScreen",              shell:false},
  {path:"/auth/setup",               screen:"ProfileSetupScreen",     shell:false},
  {path:"/home",                     screen:"HomeScreen",             shell:true},
  {path:"/explore",                  screen:"ExploreScreen",          shell:true},
  {path:"/explore/results",          screen:"SearchResultsScreen",    shell:true},
  {path:"/explore/map",              screen:"MapViewScreen",          shell:true},
  {path:"/post/category",            screen:"SelectCategoryScreen",   shell:true},
  {path:"/post/form",                screen:"AdFormScreen",           shell:false},
  {path:"/post/photos",              screen:"AddPhotosScreen",        shell:false},
  {path:"/post/location",            screen:"LocationPriceScreen",    shell:false},
  {path:"/post/preview",             screen:"AdPreviewScreen",        shell:false},
  {path:"/post/success",             screen:"AdSuccessScreen",        shell:false},
  {path:"/saved",                    screen:"SavedScreen",            shell:true},
  {path:"/saved/watchlist/:id",      screen:"WatchlistResultsScreen", shell:true},
  {path:"/profile",                  screen:"ProfileScreen",          shell:true},
  {path:"/profile/my-ads",           screen:"MyAdsScreen",           shell:false},
  {path:"/profile/performance/:id",  screen:"AdPerformanceScreen",   shell:false},
  {path:"/profile/boost/:id",        screen:"BoostAdScreen",         shell:false},
  {path:"/profile/subscription",     screen:"SubscriptionScreen",    shell:false},
  {path:"/profile/verify",           screen:"VerificationScreen",    shell:false},
  {path:"/profile/reviews",          screen:"MyReviewsScreen",       shell:false},
  {path:"/settings",                 screen:"SettingsScreen",        shell:false},
  {path:"/ad/:id",                   screen:"AdDetailScreen",        shell:false},
  {path:"/seller/:id",               screen:"SellerProfileScreen",   shell:false},
  {path:"/photos/:adId",             screen:"PhotoViewerScreen",     shell:false},
  {path:"/notifications",            screen:"NotificationsScreen",   shell:false},
  {path:"/payment",                  screen:"PaymentWebViewScreen",  shell:false},
  {path:"/payment/success",          screen:"PaymentSuccessScreen",  shell:false},
  {path:"/admin",                    screen:"ModeratorDashboard",    shell:false},
];

const NAV = [
  {icon:"🏠",label:"الرئيسية",route:"/home"},
  {icon:"🔍",label:"اكتشف",   route:"/explore"},
  {icon:"➕",label:"أضف",      route:"/post/category",highlight:true},
  {icon:"❤️",label:"المحفوظة",route:"/saved"},
  {icon:"👤",label:"حسابي",   route:"/profile"},
];

// ══════════════════════════════════════
//  COMPONENT
// ══════════════════════════════════════
function WidgetTree({ widgets }) {
  return (
    <div style={{background:"#0F172A",borderRadius:"8px",padding:"12px 14px",fontFamily:"'IBM Plex Mono',monospace",fontSize:"11px",lineHeight:2,overflow:"auto",maxHeight:"220px"}}>
      {widgets.map((w,i)=>{
        const indent = w.match(/^(\s+)/)?.[1]?.length || 0;
        const isWidget = !w.trim().startsWith("//");
        return (
          <div key={i} style={{paddingRight:`${indent*6}px`,color:
            w.includes("Consumer") || w.includes("Provider") ? "#FCA5A5" :
            w.includes("Button") || w.includes("FAB") ? C.a500 :
            indent===0 ? "#7DD3FC" :
            indent<=2 ? "#BAE6FD" :
            "#94A3B8"
          }}>{w}</div>
        );
      })}
    </div>
  );
}

function ScreenCard({ s, isSelected, onClick }) {
  const gc = GC[s.g];
  return (
    <div onClick={onClick} style={{
      background: isSelected ? gc.bg : C.n0,
      border: `1.5px solid ${isSelected ? gc.fg : C.n200}`,
      borderRadius:"12px",padding:"10px 14px",cursor:"pointer",
      transition:"all 0.15s",
    }}>
      <div style={{fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:600,color:isSelected?gc.fg:C.n600,marginBottom:"3px"}}>{s.name}</div>
      <div style={{fontSize:"11px",color:isSelected?gc.fg:C.n500}}>{s.ar}</div>
      <div style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"10px",color:isSelected?gc.fg:C.n400,marginTop:"3px",opacity:0.8}}>{s.route}</div>
    </div>
  );
}

export default function WaslaFlutter() {
  const [tab, setTab] = useState("screens");
  const [selScreen, setSelScreen] = useState("splash");
  const [groupFilter, setGroupFilter] = useState("all");

  const currentScreen = SCREENS.find(s=>s.id===selScreen);
  const gc = currentScreen ? GC[currentScreen.g] : GC.home;

  const filteredScreens = groupFilter==="all"
    ? SCREENS
    : SCREENS.filter(s=>s.g===groupFilter);

  const groupCounts = Object.fromEntries(
    Object.keys(GC).map(g=>[g, SCREENS.filter(s=>s.g===g).length])
  );

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
              <span style={{background:"rgba(255,255,255,0.15)",color:"rgba(255,255,255,0.75)",padding:"2px 10px",borderRadius:"20px",fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace"}}>Flutter Screens v1.0</span>
            </div>
            <p style={{color:"rgba(255,255,255,0.5)",fontSize:"12px",marginTop:"3px"}}>
              {SCREENS.length} شاشة · {ROUTES.length} Route · {PROVIDERS.length} Riverpod Provider
            </p>
          </div>
          <div style={{display:"flex",gap:"6px",flexWrap:"wrap"}}>
            {["Flutter","Riverpod","Go Router","Supabase"].map(t=>(
              <span key={t} style={{background:"rgba(255,255,255,0.12)",border:"1px solid rgba(255,255,255,0.2)",color:"rgba(255,255,255,0.8)",padding:"4px 10px",borderRadius:"6px",fontSize:"11px"}}>{t}</span>
            ))}
          </div>
        </div>
        <div style={{display:"flex",gap:"2px"}}>
          {[{id:"screens",ar:`الشاشات (${SCREENS.length})`},{id:"routes",ar:"Go Router"},{id:"state",ar:`Riverpod (${PROVIDERS.length})`},{id:"nav",ar:"Navigation"}].map(t=>(
            <button key={t.id} onClick={()=>setTab(t.id)} style={{
              background:tab===t.id?"rgba(255,255,255,0.15)":"transparent",
              border:"none",borderBottom:tab===t.id?`3px solid ${C.a500}`:"3px solid transparent",
              padding:"9px 16px",cursor:"pointer",fontSize:"13px",fontFamily:"'Cairo',sans-serif",
              fontWeight:tab===t.id?700:500,color:tab===t.id?"#FFF":"rgba(255,255,255,0.55)",
              borderRadius:"6px 6px 0 0",transition:"all 0.15s",
            }}>{t.ar}</button>
          ))}
        </div>
      </div>

      <div style={{maxWidth:"1140px",margin:"0 auto",padding:"24px 20px 60px"}}>

        {/* ══ SCREENS ══ */}
        {tab==="screens" && (
          <div style={{display:"grid",gridTemplateColumns:"320px 1fr",gap:"18px"}}>
            {/* Left: filter + screen list */}
            <div style={{display:"flex",flexDirection:"column",gap:"10px"}}>
              <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",overflow:"hidden"}}>
                <button onClick={()=>setGroupFilter("all")} style={{
                  width:"100%",padding:"9px 14px",display:"flex",justifyContent:"space-between",
                  background:groupFilter==="all"?C.p50:"transparent",border:"none",
                  borderBottom:`1px solid ${C.n100}`,cursor:"pointer",
                  fontSize:"12px",fontFamily:"'Cairo',sans-serif",fontWeight:groupFilter==="all"?700:400,
                  color:groupFilter==="all"?C.p600:C.n600,
                }}>
                  <span>📱 كل الشاشات</span>
                  <span style={{fontSize:"10px",background:C.p100,color:C.p600,padding:"1px 7px",borderRadius:"10px",fontWeight:700}}>{SCREENS.length}</span>
                </button>
                {Object.entries(GC).map(([k,v])=>(
                  <button key={k} onClick={()=>setGroupFilter(k)} style={{
                    width:"100%",padding:"9px 14px",display:"flex",justifyContent:"space-between",alignItems:"center",
                    background:groupFilter===k?v.bg:"transparent",border:"none",
                    borderBottom:`1px solid ${C.n100}`,cursor:"pointer",
                    fontSize:"12px",fontFamily:"'Cairo',sans-serif",fontWeight:groupFilter===k?700:400,
                    color:groupFilter===k?v.fg:C.n600,
                  }}>
                    <span>{v.icon} {k==="onboarding"?"الـ Onboarding":k==="home"?"الرئيسية":k==="explore"?"الاكتشاف":k==="post"?"نشر إعلان":k==="saved"?"المحفوظة":k==="profile"?"الملف الشخصي":k==="payment"?"الدفع":"الإدارة"}</span>
                    <span style={{fontSize:"10px",background:groupFilter===k?`${v.fg}22`:C.n100,color:groupFilter===k?v.fg:C.n500,padding:"1px 7px",borderRadius:"10px",fontWeight:700}}>{groupCounts[k]}</span>
                  </button>
                ))}
              </div>
              <div style={{display:"flex",flexDirection:"column",gap:"6px",maxHeight:"500px",overflowY:"auto"}}>
                {filteredScreens.map(s=>(
                  <ScreenCard key={s.id} s={s} isSelected={selScreen===s.id} onClick={()=>setSelScreen(s.id)}/>
                ))}
              </div>
            </div>

            {/* Right: screen detail */}
            {currentScreen && (
              <div style={{display:"flex",flexDirection:"column",gap:"14px"}}>
                {/* Header */}
                <div style={{background:gc.bg,border:`1px solid ${gc.fg}33`,borderRadius:"16px",padding:"18px 20px"}}>
                  <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"6px"}}>
                    <div style={{display:"flex",alignItems:"center",gap:"10px"}}>
                      <span style={{fontSize:"22px"}}>{gc.icon}</span>
                      <div>
                        <div style={{fontSize:"18px",fontWeight:900,color:gc.fg,fontFamily:"'IBM Plex Mono',monospace"}}>{currentScreen.name}</div>
                        <div style={{fontSize:"12px",color:gc.fg,opacity:0.8}}>{currentScreen.ar}</div>
                      </div>
                    </div>
                    <div style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:gc.fg,background:`${gc.fg}18`,padding:"4px 12px",borderRadius:"6px",fontWeight:600}}>{currentScreen.route}</div>
                  </div>
                  <p style={{fontSize:"13px",color:gc.fg,opacity:0.85,lineHeight:1.6}}>{currentScreen.purpose}</p>
                </div>

                <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"14px"}}>
                  {/* Widget Tree */}
                  <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",padding:"14px 16px"}}>
                    <div style={{fontSize:"11px",fontWeight:800,color:C.n500,letterSpacing:"0.07em",marginBottom:"10px"}}>WIDGET TREE</div>
                    <WidgetTree widgets={currentScreen.widgets}/>
                  </div>

                  {/* State + APIs */}
                  <div style={{display:"flex",flexDirection:"column",gap:"12px"}}>
                    <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",padding:"14px 16px"}}>
                      <div style={{fontSize:"11px",fontWeight:800,color:C.n500,letterSpacing:"0.07em",marginBottom:"8px"}}>RIVERPOD STATE</div>
                      {currentScreen.state.length>0 ? currentScreen.state.map((s,i)=>(
                        <div key={i} style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"11px",color:"#FCA5A5",background:"#1E293B",borderRadius:"5px",padding:"3px 8px",marginBottom:"4px"}}>{s}</div>
                      )) : <div style={{fontSize:"12px",color:C.n400}}>لا يحتاج state خارجي</div>}
                    </div>
                    <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",padding:"14px 16px"}}>
                      <div style={{fontSize:"11px",fontWeight:800,color:C.n500,letterSpacing:"0.07em",marginBottom:"8px"}}>API CALLS</div>
                      {currentScreen.apis.length>0 ? currentScreen.apis.map((a,i)=>{
                        const m=a.split(" ")[0];
                        const ms={GET:"#86EFAC",POST:"#7DD3FC",PATCH:"#FCD34D",DELETE:"#FCA5A5"}[m]||"#94A3B8";
                        return (
                          <div key={i} style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"11px",color:"#94A3B8",background:"#0F172A",borderRadius:"5px",padding:"4px 8px",marginBottom:"4px",lineHeight:1.5}}>
                            <span style={{color:ms,fontWeight:700}}>{m} </span>
                            <span>{a.replace(m+" ","")}</span>
                          </div>
                        );
                      }) : <div style={{fontSize:"12px",color:C.n400}}>لا يستدعي APIs</div>}
                    </div>
                    <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",padding:"14px 16px"}}>
                      <div style={{fontSize:"11px",fontWeight:800,color:C.n500,letterSpacing:"0.07em",marginBottom:"8px"}}>NAVIGATION →</div>
                      {currentScreen.navTo.map((n,i)=>(
                        <div key={i} style={{fontSize:"12px",color:C.p600,marginBottom:"4px",fontFamily:"'IBM Plex Mono',monospace"}}>{n}</div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* ══ ROUTES ══ */}
        {tab==="routes" && (
          <div>
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden",marginBottom:"16px"}}>
              <div style={{padding:"14px 18px",background:C.n50,borderBottom:`1px solid ${C.n100}`}}>
                <h3 style={{fontSize:"15px",fontWeight:900,color:C.n900}}>Go Router — التوجيه الكامل</h3>
                <p style={{fontSize:"12px",color:C.n500,marginTop:"2px"}}>
                  <span style={{background:"#DCFCE7",color:"#15803D",padding:"1px 6px",borderRadius:"4px",fontFamily:"'IBM Plex Mono',monospace",fontSize:"11px",fontWeight:600}}>Shell</span>
                  {" "} = ضمن الـ Bottom Nav ·
                  <span style={{background:"#FEE2E2",color:C.red,padding:"1px 6px",borderRadius:"4px",fontFamily:"'IBM Plex Mono',monospace",fontSize:"11px",fontWeight:600,marginRight:"4px"}}> Full</span>
                  {" "} = شاشة كاملة بدون Nav Bar
                </p>
              </div>
              <div style={{overflowX:"auto"}}>
                <table style={{width:"100%",borderCollapse:"collapse",fontSize:"12px"}}>
                  <thead>
                    <tr style={{background:C.n50}}>
                      {["المسار","الشاشة","النوع","الوصف"].map(h=>(
                        <th key={h} style={{padding:"9px 14px",textAlign:"right",fontWeight:700,color:C.n600,borderBottom:`1.5px solid ${C.n200}`,fontSize:"11px"}}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {ROUTES.map((r,i)=>{
                      const s = SCREENS.find(s=>s.name===r.screen);
                      return (
                        <tr key={i} style={{background:i%2===0?C.n0:C.n50}}>
                          <td style={{padding:"9px 14px",borderBottom:`1px solid ${C.n100}`,fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.p600,fontWeight:600}}>{r.path}</td>
                          <td style={{padding:"9px 14px",borderBottom:`1px solid ${C.n100}`,fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",color:C.n700}}>{r.screen}</td>
                          <td style={{padding:"9px 14px",borderBottom:`1px solid ${C.n100}`}}>
                            <span style={{fontSize:"10px",fontWeight:700,padding:"2px 7px",borderRadius:"5px",
                              background:r.shell?"#DCFCE7":"#FEE2E2",
                              color:r.shell?"#15803D":C.red}}>
                              {r.shell?"Shell":"Full"}
                            </span>
                          </td>
                          <td style={{padding:"9px 14px",borderBottom:`1px solid ${C.n100}`,fontSize:"12px",color:C.n500}}>{s?.ar||""}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
            {/* GoRouter dart snippet */}
            <div style={{background:"#0F172A",borderRadius:"14px",padding:"18px 20px"}}>
              <div style={{fontSize:"11px",color:"#64748B",marginBottom:"12px",fontFamily:"'IBM Plex Mono',monospace"}}>// lib/router/app_router.dart</div>
              <div style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",lineHeight:1.8,color:"#94A3B8"}}>
                {[
                  {t:"final",c:"#FCA5A5"},{t:" router",c:"#7DD3FC"},{t:" = ",c:"#94A3B8"},{t:"GoRouter",c:"#86EFAC"},{t:"(",c:"#94A3B8"},
                ].map((p,i)=><span key={i} style={{color:p.c}}>{p.t}</span>)}
                <div style={{paddingRight:"16px",color:"#94A3B8"}}>
                  <div><span style={{color:"#7DD3FC"}}>redirect</span>: <span style={{color:"#94A3B8"}}>(ctx, state) {"=>"} authGuard(ctx, state),</span></div>
                  <div><span style={{color:"#7DD3FC"}}>routes</span>: {"["}</div>
                  <div style={{paddingRight:"16px"}}>
                    <div><span style={{color:"#FCD34D"}}>GoRoute</span>(path: <span style={{color:"#86EFAC"}}>'/splash'</span>, builder: SplashScreen),</div>
                    <div style={{color:"#64748B"}}>// ... Onboarding routes</div>
                    <div><span style={{color:"#FCA5A5"}}>ShellRoute</span>( <span style={{color:"#64748B"}}>// Bottom Nav Shell</span></div>
                    <div style={{paddingRight:"16px"}}>
                      <div>builder: (ctx, state, child) {"=>"} <span style={{color:"#86EFAC"}}>MainShell</span>(child),</div>
                      <div>routes: [/home, /explore, /post/category, /saved, /profile],</div>
                    </div>
                    <div>),</div>
                    <div><span style={{color:"#64748B"}}>// Full-screen routes (no shell)</span></div>
                    <div><span style={{color:"#FCD34D"}}>GoRoute</span>(path: <span style={{color:"#86EFAC"}}>'/ad/:id'</span>, builder: AdDetailScreen),</div>
                    <div><span style={{color:"#FCD34D"}}>GoRoute</span>(path: <span style={{color:"#86EFAC"}}>'/payment'</span>, builder: PaymentWebViewScreen),</div>
                    <div style={{color:"#64748B"}}>// ... more routes</div>
                  </div>
                  <div>{"]"}</div>
                </div>
                <span style={{color:"#94A3B8"}}>);</span>
              </div>
            </div>
          </div>
        )}

        {/* ══ STATE (RIVERPOD) ══ */}
        {tab==="state" && (
          <div>
            <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"12px",marginBottom:"16px"}}>
              {PROVIDERS.map((p,i)=>(
                <div key={i} style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"12px",padding:"14px 16px"}}>
                  <div style={{display:"flex",alignItems:"center",gap:"8px",marginBottom:"6px"}}>
                    <span style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",fontWeight:700,color:C.p600}}>{p.name}</span>
                  </div>
                  <span style={{fontSize:"10px",background:
                    p.type.includes("Stream")?"#EDE9FE":
                    p.type.includes("family")?"#FEF9C3":
                    p.type.includes("StateNotifier")?"#FEE2E2":C.p50,
                    color:
                    p.type.includes("Stream")?"#5B21B6":
                    p.type.includes("family")?"#854D0E":
                    p.type.includes("StateNotifier")?C.red:C.p600,
                    padding:"2px 8px",borderRadius:"5px",fontWeight:700,fontFamily:"'IBM Plex Mono',monospace",
                    display:"inline-block",marginBottom:"6px"}}>{p.type}</span>
                  <div style={{fontSize:"12px",color:C.n600,lineHeight:1.5}}>{p.desc}</div>
                </div>
              ))}
            </div>
            <div style={{background:"#0F172A",borderRadius:"14px",padding:"18px 20px"}}>
              <div style={{fontSize:"11px",color:"#64748B",marginBottom:"12px",fontFamily:"'IBM Plex Mono',monospace"}}>// lib/providers/providers.dart — أمثلة</div>
              <div style={{fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px",lineHeight:2,color:"#94A3B8"}}>
                {[
                  "// Auth State",
                  "final authStateProvider = StreamProvider((ref) =>",
                  "  Supabase.instance.client.auth.onAuthStateChange);",
                  "",
                  "// Ads with filters (StateNotifier)",
                  "final adsListProvider = StateNotifierProvider<AdsNotifier, AdsState>(",
                  "  (ref) => AdsNotifier(ref.read(supabaseProvider)));",
                  "",
                  "// Single ad (family)",
                  "final adDetailProvider = FutureProvider.family<Ad, String>(",
                  "  (ref, id) => ref.read(adRepoProvider).getAdById(id));",
                  "",
                  "// Favorites (realtime)",
                  "final favoritesProvider = StreamProvider<List<Favorite>>(",
                  "  (ref) => ref.read(favRepoProvider).watchFavorites());",
                ].map((line,i)=>(
                  <div key={i} style={{color:
                    line.startsWith("//")?"#64748B":
                    line.includes("final")?"#FCA5A5":
                    line.includes("Provider")?"#86EFAC":
                    line.includes("Supabase")||line.includes("Notifier")?"#7DD3FC":"#94A3B8"
                  }}>{line||"\u00A0"}</div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* ══ NAV ══ */}
        {tab==="nav" && (
          <div style={{display:"flex",flexDirection:"column",gap:"16px"}}>
            {/* Bottom Nav Mockup */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"16px",padding:"20px",textAlign:"center"}}>
              <h3 style={{fontSize:"15px",fontWeight:900,color:C.n900,marginBottom:"16px",textAlign:"right"}}>Bottom Navigation Bar</h3>
              <div style={{maxWidth:"360px",margin:"0 auto",background:`linear-gradient(180deg,${C.n50},${C.n100})`,borderRadius:"24px",padding:"24px 12px 12px",boxShadow:"0 8px 32px rgba(0,0,0,0.1)"}}>
                <div style={{background:C.n0,borderRadius:"16px",height:"200px",marginBottom:"12px",display:"flex",alignItems:"center",justifyContent:"center",color:C.n300,fontSize:"14px"}}>محتوى الشاشة</div>
                <div style={{background:C.n0,borderRadius:"16px",padding:"12px 8px",display:"flex",justifyContent:"space-around",boxShadow:"0 -2px 12px rgba(0,0,0,0.06)"}}>
                  {NAV.map(n=>(
                    <div key={n.route} style={{display:"flex",flexDirection:"column",alignItems:"center",gap:"3px",flex:1}}>
                      <div style={{
                        width:n.highlight?48:36,height:n.highlight?48:36,
                        background:n.highlight?C.p600:C.n50,
                        borderRadius:n.highlight?"50%":"10px",
                        display:"flex",alignItems:"center",justifyContent:"center",
                        fontSize:n.highlight?20:16,
                        boxShadow:n.highlight?"0 4px 14px rgba(13,122,132,0.45)":undefined,
                        marginTop:n.highlight?"-22px":0,
                        border:n.highlight?`3px solid ${C.n0}`:undefined,
                      }}>{n.icon}</div>
                      {!n.highlight && <span style={{fontSize:"10px",color:C.n500,fontWeight:600}}>{n.label}</span>}
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Screen groups summary */}
            <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:"12px"}}>
              {Object.entries(GC).map(([k,v])=>(
                <div key={k} style={{background:v.bg,border:`1px solid ${v.fg}33`,borderRadius:"12px",padding:"14px 16px",textAlign:"center"}}>
                  <div style={{fontSize:"22px",marginBottom:"6px"}}>{v.icon}</div>
                  <div style={{fontSize:"13px",fontWeight:700,color:v.fg,marginBottom:"2px"}}>{SCREENS.filter(s=>s.g===k).length} شاشات</div>
                  <div style={{fontSize:"11px",color:v.fg,opacity:0.8}}>
                    {k==="onboarding"?"Onboarding":k==="home"?"الرئيسية":k==="explore"?"الاكتشاف":k==="post"?"نشر إعلان":k==="saved"?"المحفوظة":k==="profile"?"الملف الشخصي":k==="payment"?"الدفع":"الإدارة"}
                  </div>
                </div>
              ))}
            </div>

            {/* Architecture notes */}
            <div style={{background:C.p50,border:`1px solid ${C.p100}`,borderRadius:"14px",padding:"18px 20px"}}>
              <h4 style={{fontSize:"14px",fontWeight:800,color:C.p700,marginBottom:"14px"}}>📐 قرارات معمارية Flutter</h4>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"12px"}}>
                {[
                  {title:"State: flutter_riverpod",desc:"أفضل من Provider و BLoC لهذا المشروع — أقل boilerplate وأكثر مرونة"},
                  {title:"Navigation: go_router",desc:"يدعم Deep linking وWeb URLs — ضروري لمشاركة روابط الإعلانات"},
                  {title:"HTTP: supabase_flutter",desc:"SDK رسمي — يدير Auth + DB + Storage + Realtime بـ package واحد"},
                  {title:"Images: cached_network_image",desc:"Cache تلقائي + placeholder + error widget — ضروري لسرعة التحميل"},
                  {title:"Maps: google_maps_flutter",desc:"خريطة تفاعلية مع clusters للإعلانات القريبة"},
                  {title:"Animations: lottie",desc:"للـ Success screens والـ Empty states — تجربة مستخدم ممتازة"},
                ].map(item=>(
                  <div key={item.title} style={{background:C.n0,borderRadius:"10px",padding:"12px 14px"}}>
                    <div style={{fontSize:"12px",fontWeight:800,color:C.p600,fontFamily:"'IBM Plex Mono',monospace",marginBottom:"4px"}}>{item.title}</div>
                    <div style={{fontSize:"12px",color:C.n600,lineHeight:1.6}}>{item.desc}</div>
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
