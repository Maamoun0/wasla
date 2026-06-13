import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Shell & Skeletons
import 'main_shell.dart';
import 'screen_skeletons.dart';

// Screens
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/explore_screen.dart';
import '../../features/home/presentation/saved_screen.dart';
import '../../features/home/presentation/select_category_screen.dart';
import '../../features/home/presentation/ad_form_screen.dart';
import '../../features/home/presentation/add_photos_screen.dart';
import '../../features/home/presentation/location_price_screen.dart';
import '../../features/home/presentation/ad_preview_screen.dart';
import '../../features/home/presentation/ad_success_screen.dart';
import '../../features/home/presentation/ad_detail_screen.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_detail_screen.dart';
import '../../features/kyc/presentation/verification_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      
      final path = state.uri.path;

      // قائمة بالمسارات المحمية التي تتطلب تسجيل الدخول
      final isProtectedRoute = path.startsWith('/post') || 
                               path.startsWith('/saved') || 
                               path.startsWith('/profile') || 
                               path.startsWith('/chat') || 
                               path.startsWith('/payment') || 
                               path.startsWith('/admin');

      // إذا كان غير مسجل دخول ويحاول دخول صفحة محمية
      if (!isLoggedIn && isProtectedRoute) {
        return '/login';
      }

      // إذا كان مسجل دخول ويحاول العودة لصفحات تسجيل الدخول
      if (isLoggedIn && (path == '/login' || path == '/verify-otp' || path == '/onboarding')) {
        return '/home';
      }

      return null;
    },
    routes: [
      // ── Full Screen (No Shell) ──
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpVerificationScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/auth/setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // ── Shell Routes (With Bottom Navigation Bar) ──
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/post/category',
            builder: (context, state) => const SelectCategoryScreen(),
          ),
          GoRoute(
            path: '/saved',
            builder: (context, state) => const SavedScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Full-screen sub-routes ──
      GoRoute(
        path: '/explore/results',
        builder: (context, state) => const SearchResultsScreen(),
      ),
      GoRoute(
        path: '/explore/map',
        builder: (context, state) => const MapViewScreen(),
      ),
      GoRoute(
        path: '/ad/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AdDetailScreen(adId: id);
        },
      ),
      GoRoute(
        path: '/seller/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SellerProfileScreen(id: id);
        },
      ),
      GoRoute(
        path: '/photos/:adId',
        builder: (context, state) {
          final adId = state.pathParameters['adId'] ?? '';
          return PhotoViewerScreen(adId: adId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ── Post Ad Flow ──
      GoRoute(
        path: '/post/form',
        builder: (context, state) => const AdFormScreen(),
      ),
      GoRoute(
        path: '/post/photos',
        builder: (context, state) => const AddPhotosScreen(),
      ),
      GoRoute(
        path: '/post/location',
        builder: (context, state) => const LocationPriceScreen(),
      ),
      GoRoute(
        path: '/post/preview',
        builder: (context, state) => const AdPreviewScreen(),
      ),
      GoRoute(
        path: '/post/success',
        builder: (context, state) => const AdSuccessScreen(),
      ),

      // ── Saved sub-routes ──
      GoRoute(
        path: '/saved/watchlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return WatchlistResultsScreen(id: id);
        },
      ),

      // ── Profile sub-routes ──
      GoRoute(
        path: '/profile/my-ads',
        builder: (context, state) => const MyAdsScreen(),
      ),
      GoRoute(
        path: '/profile/performance/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AdPerformanceScreen(id: id);
        },
      ),
      GoRoute(
        path: '/profile/boost/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BoostAdScreen(id: id);
        },
      ),
      GoRoute(
        path: '/profile/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/profile/verify',
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: '/profile/reviews',
        builder: (context, state) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // ── Chat Flow ──
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ChatDetailScreen(conversationId: id);
        },
      ),

      // ── Payment WebView ──
      GoRoute(
        path: '/payment',
        builder: (context, state) => const PaymentWebViewScreen(),
      ),
      GoRoute(
        path: '/payment/success',
        builder: (context, state) => const PaymentSuccessScreen(),
      ),

      // ── Admin moderator ──
      GoRoute(
        path: '/admin',
        builder: (context, state) => const ModeratorDashboard(),
      ),
    ],
  );
});
