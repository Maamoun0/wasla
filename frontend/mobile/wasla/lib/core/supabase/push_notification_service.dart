import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// حالة تهيئة Firebase
bool _firebaseInitialized = false;

class PushNotificationService {
  static FirebaseMessaging? _fcm;

  /// تهيئة Firebase — إذا فشلت لأي سبب، يستمر التطبيق بدون إشعارات
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _firebaseInitialized = true;
      _fcm = FirebaseMessaging.instance;

      // Handle Background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Setup Foreground presentation options for iOS
      await _fcm!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) print("✅ Firebase initialized successfully");
    } catch (e) {
      _firebaseInitialized = false;
      if (kDebugMode) {
        print("⚠️ Firebase initialization failed (notifications disabled): $e");
        print("   Make sure google-services.json is placed in android/app/");
      }
      // لا نُعيد رمي الاستثناء — التطبيق يعمل بدون إشعارات
    }
  }

  /// طلب صلاحيات الإشعارات
  static Future<bool> requestPermission() async {
    if (!_firebaseInitialized || _fcm == null) return false;
    try {
      NotificationSettings settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      if (kDebugMode) print("⚠️ requestPermission error: $e");
      return false;
    }
  }

  /// مزامنة FCM token مع Supabase
  static Future<void> syncToken() async {
    if (!_firebaseInitialized || _fcm == null) return;
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      String? token = await _fcm!.getToken();
      if (token != null) {
        if (kDebugMode) print("FCM Token: $token");

        await supabase.from('push_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'is_active': true,
          'last_seen_at': DateTime.now().toIso8601String(),
        });
      }

      // Listen to token refreshes
      _fcm!.onTokenRefresh.listen((newToken) async {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) return;
        await Supabase.instance.client.from('push_tokens').upsert({
          'user_id': currentUser.id,
          'token': newToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'is_active': true,
          'last_seen_at': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      if (kDebugMode) print("⚠️ syncToken error: $e");
    }
  }

  static Future<void> deleteToken() async {
    if (!_firebaseInitialized || _fcm == null) return;
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      String? token = await _fcm!.getToken();
      if (user != null && token != null) {
        await supabase
            .from('push_tokens')
            .delete()
            .match({'user_id': user.id, 'token': token});
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ deleteToken error: $e");
    }
  }

  /// هل Firebase مُهيَّأ وجاهز؟
  static bool get isAvailable => _firebaseInitialized;
}

/// معالج رسائل الخلفية — يجب أن يكون top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    // Handle background notification logic here if needed
  } catch (e) {
    // Ignore if Firebase not available
  }
}
