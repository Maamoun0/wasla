import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/observability/error_reporting.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/push_notification_service.dart';
import 'features/notifications/providers/notifications_provider.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();

    // ── Status Bar Style ──────────────────────────────────────────
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // ── Portrait Only ─────────────────────────────────────────────
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // ── Supabase (يجب أن يكون أولاً) ─────────────────────────────
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      debug: kDebugMode,
    );

    // ── Firebase & Notifications (بعد Supabase) ──────────────────
    await PushNotificationService.initialize();

    await ErrorReporting.run(() => runApp(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
          path: 'assets/translations',
          fallbackLocale: const Locale('ar', 'EG'),
          child: const WaslaApp(),
        ),
      ),
    ));
  } catch (e, stack) {
    debugPrint("CRITICAL ERROR DURING STARTUP: $e");
    debugPrint(stack.toString());
    await ErrorReporting.capture(e, stack);

    
    // Fallback app to show the error instead of a black screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "خطأ في تشغيل التطبيق:\n$e",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supabase Client Shortcut ──────────────────────────────────
final supabase = Supabase.instance.client;

class WaslaApp extends ConsumerStatefulWidget {
  const WaslaApp({super.key});

  @override
  ConsumerState<WaslaApp> createState() => _WaslaAppState();
}

class _WaslaAppState extends ConsumerState<WaslaApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationInteractions();
  }

  void _setupNotificationInteractions() {
    // لا نُسجّل المستمعين إذا لم يكن Firebase جاهزاً
    if (!PushNotificationService.isAvailable) return;

    // Handle foreground notifications with a snackbar (Piece 5.1)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text(notification.body ?? '', style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary600,
            action: SnackBarAction(
              label: 'عرض',
              textColor: Colors.white,
              onPressed: () => _handleNotificationRouting(message.data),
            ),
          ),
        );
      }
    });

    // Handle taps on notifications (Piece 5.2)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationRouting(message.data);
    });
  }

  void _handleNotificationRouting(Map<String, dynamic> data) {
    final route = notificationRoute(data);
    if (route != null) ref.read(routerProvider).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,

      // ── Theme ───────────────────────────────────────────────
      theme: AppTheme.light,
      themeMode: ThemeMode.light,

      // ── Router ──────────────────────────────────────────────
      routerConfig: router,

      // ── Locale & RTL Config ─────────────────────────────────
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,

      // ── RTL ─────────────────────────────────────────────────
      builder: (context, child) {
        return Directionality(
          textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: child!,
        );
      },
    );
  }
}
