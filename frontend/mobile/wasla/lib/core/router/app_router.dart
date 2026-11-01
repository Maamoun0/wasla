import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/auth/providers/auth_provider.dart';
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
import '../../features/profile/screens/payment_webview_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/notification_settings_screen.dart';
import '../../shared/widgets/bottom_nav_shell.dart';
import '../../shared/providers/ads_provider.dart';
import '../../features/legal/legal_provider.dart';
import '../../features/legal/legal_screen.dart';

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
  static const String notificationSettings = '/settings/notifications';

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
  static const String paymentWebView = '/profile/payment';

  // Admin
  static const String admin         = '/admin';
  static const String legal         = '/legal/:kind';
}

/// Location of Explore showing [filter] (empty filter: plain /explore).
String exploreLocation(AdsFilter filter) {
  final query = adsFilterToQuery(filter);
  return Uri(path: AppRoutes.explore, queryParameters: query.isEmpty ? null : query).toString();
}

// ── Router Provider ─────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) => _authGuard(context, state, ref),
    // يُعيد توجيه المستخدم تلقائياً عند تغيّر حالة المصادقة (Google OAuth)
    refreshListenable: _AuthStateListenable(ref),
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
        builder: (ctx, state) => AuthScreen(returnTo: safeReturnPath(state.uri.queryParameters['from'])),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (ctx, state) => OtpScreen(
          returnTo: safeReturnPath(state.uri.queryParameters['from']),
          phone: state.uri.queryParameters['phone'] ?? '',
          initialWaitSeconds: int.tryParse(state.uri.queryParameters['wait'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (ctx, state) => ProfileSetupScreen(returnTo: safeReturnPath(state.uri.queryParameters['from'])),
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
            builder: (ctx, state) => ExploreScreen(
              initialFilter: adsFilterFromQuery(state.uri.queryParameters),
            ),
          ),
          GoRoute(
            path: AppRoutes.postCategory,
            builder: (ctx, state) => const SelectCategoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.saved,
            builder: (ctx, state) => SavedScreen(
              initialTab: state.uri.queryParameters['tab'] == 'alerts' ? 1 : 0,
            ),
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
        path: AppRoutes.legal,
        builder: (ctx, state) {
          final kind = LegalKind.fromId(state.pathParameters['kind']);
          return kind == null ? const _MissingLegalScreen() : LegalScreen(kind: kind);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (ctx, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (ctx, state) => const NotificationSettingsScreen(),
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
      GoRoute(
        path: AppRoutes.paymentWebView,
        builder: (ctx, state) => paymentScreenFor(state.extra),
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

// ── Auth State Listenable ────────────────────────────────────────
// يُخطِر GoRouter عند تغيّر حالة المصادقة (ضروري لـ Google OAuth)
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

// ── Auth Guard ───────────────────────────────────────────────────
/// The payment page for the data the paying screen passed in `extra`, or a
/// "start again" page when there is none (restored app, typed URL).
Widget paymentScreenFor(Object? extra) {
  if (extra is! Map<String, dynamic> ||
      extra['paymentUrl'] is! String ||
      extra['transactionId'] is! String ||
      extra['paymentType'] is! String) {
    return const _MissingPaymentScreen();
  }
  return PaymentWebViewScreen(
    paymentUrl: extra['paymentUrl'] as String,
    transactionId: extra['transactionId'] as String,
    paymentType: extra['paymentType'] as String,
    referenceId: extra['referenceId'] as String?,
  );
}

/// Where to go back to after signing in: only a path inside the app (never
/// another host or scheme, never the sign-in pages themselves).
String? safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) return null;
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path == AppRoutes.auth || uri.path.startsWith('${AppRoutes.auth}/')) return null;
  return uri.toString();
}

/// The sign-in page, remembering where to return.
String authLocation({String? from}) {
  final back = safeReturnPath(from);
  return Uri(path: AppRoutes.auth, queryParameters: back == null ? null : {'from': back}).toString();
}

/// Pages a guest may open. Browsing (ads, sellers, photos, search) is public;
/// Saved, Profile and Notifications show their own sign-in prompt. Everything
/// else (posting, payments, my ads, settings…) needs a session.
bool isPublicLocation(String location) {
  const exact = {
    AppRoutes.splash, AppRoutes.onboarding, AppRoutes.auth, AppRoutes.otp,
    AppRoutes.home, AppRoutes.explore, AppRoutes.saved, AppRoutes.profile, AppRoutes.notifications,
  };
  final path = Uri.parse(location).path;
  if (exact.contains(path)) return true;
  // /ad/:id, /seller/:id, /photos/:adId (one segment after the prefix).
  return RegExp(r'^/(ad|seller|photos|legal)/[^/]+$').hasMatch(path);
}

String? _authGuard(BuildContext context, GoRouterState state, Ref ref) {
  final isLoggedIn = ref.read(authRepositoryProvider).currentSession != null;

  return authRedirect(isLoggedIn: isLoggedIn, matchedLocation: state.matchedLocation, uri: state.uri);
}

/// The guard's decision (null = stay).
String? authRedirect({required bool isLoggedIn, required String matchedLocation, required Uri uri}) {
  if (!isLoggedIn && !isPublicLocation(matchedLocation)) {
    return authLocation(from: uri.toString());
  }
  // Signed in while on the sign-in page (Google returns here): go back.
  if (isLoggedIn && matchedLocation == AppRoutes.auth) {
    return safeReturnPath(uri.queryParameters['from']) ?? AppRoutes.home;
  }

  return null;
}

/// Shown when the payment page is opened without a payment (e.g. app restore).
class _MissingPaymentScreen extends StatelessWidget {
  const _MissingPaymentScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدفع')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('انتهت جلسة الدفع. ابدأ عملية الدفع من جديد.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(AppRoutes.myAds),
                child: const Text('العودة لإعلاناتي'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingLegalScreen extends StatelessWidget {
  const _MissingLegalScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('الصفحة غير موجودة')));
}
