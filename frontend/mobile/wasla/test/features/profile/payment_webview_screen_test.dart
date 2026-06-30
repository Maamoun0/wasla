import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/profile/screens/payment_webview_screen.dart';

// ── Fake Realtime Channel ────────────────────────────────────────
class FakeRealtimeChannel implements RealtimeChannel {
  @override
  final String topic;

  void Function(PostgresChangePayload)? callback;

  FakeRealtimeChannel(this.topic);

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    this.callback = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus, Object?)? callback,
    Duration? timeout,
  ]) {
    callback?.call(RealtimeSubscribeStatus.subscribed, null);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fake Supabase Client ─────────────────────────────────────────
class FakeSupabaseClient implements SupabaseClient {
  final Map<String, FakeRealtimeChannel> channels = {};
  final List<RealtimeChannel> removedChannels = [];

  @override
  RealtimeChannel channel(String topic, {RealtimeChannelConfig? opts}) {
    return channels.putIfAbsent(topic, () => FakeRealtimeChannel(topic));
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removedChannels.add(channel);
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fake Postgres Payload ────────────────────────────────────────
class FakePostgresChangePayload implements PostgresChangePayload {
  @override
  final Map<String, dynamic> newRecord; // non-nullable, matching the real API

  FakePostgresChangePayload({required this.newRecord});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fake WebView Platform ────────────────────────────────────────
class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakeWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakePlatformNavigationDelegate(params);
  }
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  FutureOr<NavigationDecision> Function(NavigationRequest request)? onNavigationRequest;
  void Function(String url)? onPageStarted;
  void Function(String url)? onPageFinished;

  @override
  Future<void> setOnNavigationRequest(
    FutureOr<NavigationDecision> Function(NavigationRequest request) onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(
    void Function(String url) onPageStarted,
  ) async {
    this.onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(
    void Function(String url) onPageFinished,
  ) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnProgress(
    void Function(int progress) onProgress,
  ) async {}

  @override
  Future<void> setOnWebResourceError(
    void Function(WebResourceError error) onWebResourceError,
  ) async {}
}

class _FakeWebViewController extends PlatformWebViewController {
  static _FakeWebViewController? latestInstance;
  _FakePlatformNavigationDelegate? platformNavigationDelegate;

  _FakeWebViewController(super.params) : super.implementation() {
    latestInstance = this;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    platformNavigationDelegate = handler as _FakePlatformNavigationDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Tests ────────────────────────────────────────────────────────
void main() {
  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  group('PaymentWebViewScreen Tests', () {
    late FakeSupabaseClient fakeSupabase;
    const String testPaymentUrl = 'https://paymob.example.com/checkout?token=123';
    const String testTransactionId = 'tx-42';

    setUp(() {
      fakeSupabase = FakeSupabaseClient();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(fakeSupabase),
          ],
          child: const MaterialApp(
            home: PaymentWebViewScreen(
              paymentUrl: testPaymentUrl,
              transactionId: testTransactionId,
              paymentType: 'ad_boost',
            ),
          ),
        ),
      );
    }

    testWidgets('Renders screen elements (AppBar and WebView)', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('بوابة الدفع الآمنة'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsOneWidget);
    });

    testWidgets('Success flow: Realtime update with status=completed', (WidgetTester tester) async {
      await pumpScreen(tester);

      // Simulate success redirect
      final webViewController = _FakeWebViewController.latestInstance!;
      expect(webViewController.platformNavigationDelegate, isNotNull);
      final decision = await webViewController.platformNavigationDelegate!.onNavigationRequest!(
        const NavigationRequest(url: 'https://wasla.eg/payment/callback?success=true&id=42', isMainFrame: true),
      );
      expect(decision, NavigationDecision.prevent);
      await tester.pump();

      // Now channel is open
      const topic = 'public:transactions:id=eq.$testTransactionId';
      expect(fakeSupabase.channels.containsKey(topic), true);

      // Simulate completed status
      fakeSupabase.channels[topic]!.callback!(
        FakePostgresChangePayload(newRecord: {'status': 'completed'}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('تم الدفع بنجاح'), findsOneWidget);
    });

    testWidgets('Failure flow: Realtime update with status=failed', (WidgetTester tester) async {
      await pumpScreen(tester);

      final webViewController = _FakeWebViewController.latestInstance!;
      expect(webViewController.platformNavigationDelegate, isNotNull);
      await webViewController.platformNavigationDelegate!.onNavigationRequest!(
        const NavigationRequest(url: 'https://wasla.eg/payment/callback?success=true&id=42', isMainFrame: true),
      );
      await tester.pump();

      const topic = 'public:transactions:id=eq.$testTransactionId';
      fakeSupabase.channels[topic]!.callback!(
        FakePostgresChangePayload(newRecord: {'status': 'failed'}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('فشلت المعاملة'), findsOneWidget);
    });

    testWidgets('Cancellation flow: navigate to cancel URL', (WidgetTester tester) async {
      await pumpScreen(tester);

      final webViewController = _FakeWebViewController.latestInstance!;
      expect(webViewController.platformNavigationDelegate, isNotNull);
      final decision = await webViewController.platformNavigationDelegate!.onNavigationRequest!(
        const NavigationRequest(url: 'https://wasla.eg/payment/cancel', isMainFrame: true),
      );

      expect(decision, NavigationDecision.prevent);
    });
  });
}
