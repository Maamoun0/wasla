import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/ads/screens/ad_detail_screen.dart';
import '../../features/ads/screens/seller_profile_screen.dart';
import '../../features/ads/screens/photo_viewer_screen.dart';
import '../../features/post_ad/screens/select_category_screen.dart';
import '../../features/post_ad/screens/ad_form_screen.dart';
import '../../features/post_ad/screens/add_photos_screen.dart';
import '../../features/post_ad/screens/location_price_screen.dart';
import '../../features/post_ad/screens/ad_preview_screen.dart';
import '../../features/post_ad/screens/ad_success_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/my_ads_screen.dart';
import '../../features/profile/screens/ad_performance_screen.dart';
import '../../features/profile/screens/boost_ad_screen.dart';
import '../../features/profile/screens/subscription_screen.dart';
import '../../features/profile/screens/verification_screen.dart';
import '../../features/profile/screens/my_reviews_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../shared/widgets/bottom_nav_shell.dart';

// ── Route Names ──────────────────────────────────────────────────
class AppRoutes {
  static const String splash         = '/';
  static const String onboarding     = '/onboarding';
  static const String auth           = '/auth';
  static const String otp            = '/auth/otp';
  static const String profileSetup   = '/auth/setup';

  // Shell routes (Bottom Nav)
  static const String home           = '/home';
  static const String explore        = '/explore';
  static const String postCategory   = '/post/category';
  static const String saved          = '/saved';
  static const String profile        = '/profile';

  // Full-screen routes
  static const String adDetail       = '/ad/:id';
  static const String sellerProfile  = '/seller/:id';
  static const String photoViewer    = '/photos/:adId';
  static const String notifications  = '/notifications';

  // Post Ad Wizard
  static const String postForm       = '/post/form';
  static const String postPhotos     = '/post/photos';
  static const String postLocation   = '/post/location';
  static const String postPreview    = '/post/preview';
  static const String postSuccess    = '/post/success';

  // Profile sub-screens
  static const String myAds         = '/profile/my-ads';
  static const String adPerformance = '/profile/performance/:id';
  static const String boostAd       = '/profile/boost/:id';
  static const String subscription  = '/profile/subscription';
  static const String verification  = '/profile/verify';
  static const String myReviews     = '/profile/reviews';
  static const String settings      = '/settings';

  // Admin
  static const String admin         = '/admin';
}

// ── Router Provider ─────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: _authGuard,
    routes: [
      // ── Standalone Routes ────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (ctx, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (ctx, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (ctx, state) => OtpScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (ctx, state) => const ProfileSetupScreen(),
      ),

      // ── Shell (Bottom Nav) ───────────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (ctx, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.explore,
            builder: (ctx, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: AppRoutes.postCategory,
            builder: (ctx, state) => const SelectCategoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.saved,
            builder: (ctx, state) => const SavedScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (ctx, state) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Full-Screen Routes ───────────────────────────────────
      GoRoute(
        path: AppRoutes.adDetail,
        builder: (ctx, state) => AdDetailScreen(
          adId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerProfile,
        builder: (ctx, state) => SellerProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.photoViewer,
        builder: (ctx, state) => PhotoViewerScreen(
          adId: state.pathParameters['adId']!,
          initialIndex: int.tryParse(
            state.uri.queryParameters['index'] ?? '0',
          ) ?? 0,
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (ctx, state) => const NotificationsScreen(),
      ),

      // ── Post Ad Wizard ───────────────────────────────────────
      GoRoute(
        path: AppRoutes.postForm,
        builder: (ctx, state) => const AdFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.postPhotos,
        builder: (ctx, state) => const AddPhotosScreen(),
      ),
      GoRoute(
        path: AppRoutes.postLocation,
        builder: (ctx, state) => const LocationPriceScreen(),
      ),
      GoRoute(
        path: AppRoutes.postPreview,
        builder: (ctx, state) => const AdPreviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.postSuccess,
        builder: (ctx, state) => const AdSuccessScreen(),
      ),

      // ── Profile Sub-Screens ──────────────────────────────────
      GoRoute(
        path: AppRoutes.myAds,
        builder: (ctx, state) => const MyAdsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adPerformance,
        builder: (ctx, state) => AdPerformanceScreen(
          adId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.boostAd,
        builder: (ctx, state) => BoostAdScreen(
          adId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (ctx, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.verification,
        builder: (ctx, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.myReviews,
        builder: (ctx, state) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (ctx, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (ctx, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            Text('الصفحة غير موجودة', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ctx.go(AppRoutes.home),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ── Auth Guard ───────────────────────────────────────────────────
String? _authGuard(BuildContext context, GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  final isLoggedIn = session != null;

  final publicRoutes = [
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.auth,
    AppRoutes.otp,
  ];

  final isPublicRoute = publicRoutes.contains(state.matchedLocation);

  if (!isLoggedIn && !isPublicRoute) {
    return AppRoutes.auth;
  }

  return null;
}
