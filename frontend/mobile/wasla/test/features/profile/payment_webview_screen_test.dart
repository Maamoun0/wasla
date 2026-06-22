import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';
import 'package:wasla/features/profile/screens/payment_webview_screen.dart';

class FakeRealtimeChannel implements RealtimeChannel {
    final String topic;
    void Function(PostgresChangePayload)? callback;

    FakeRealtimeChannel(this.topic);

    @override
    RealtimeChannel onPostgresChanges({
          required PostgresChangeEvent event,
          required String schema,
          String? table,
          String? filter,
          required void Function(PostgresChangePayload payload) callback,
    }) {
          this.callback = callback;
          return this;
    }

    @override
    void subscribe([void Function(String status, Object? error)? callback]) {
          if (callback != null) {
                  callback('SUBSCRIBED', null);
          }
    }

    @override
    dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSupabaseClient implements SupabaseClient {
    final Map<String, FakeRealtimeChannel> channels = {};
    final List<RealtimeChannel> removedChannels = [];

    @override
    RealtimeChannel channel(String topic) {
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

class FakePostgresChangePayload implements PostgresChangePayload {
    @override
    final Map<String, dynamic>? newRecord;

    FakePostgresChangePayload({this.newRecord});

    @override
    dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void main() {
      setUpAll(() {
            WebViewPlatform.instance = _FakeWebViewPlatform();
      });

      group('PaymentWebViewScreen Tests', () {
            late FakeSupabaseClient fakeSupabase;
            const String testPaymentUrl = 'https://paymob.example.com/checkout?token=123';
            const int testTransactionId = 42;

            setUp(() {
                    fakeSupabase = FakeSupabaseClient();
            });

            Future<void> pumpScreen(WidgetTester tester) async {
                    await tester.pumpWidget(
                              ProviderScope(
                                          overrides: [
                                                        supabaseClientProvider.overrideWithValue(fakeSupabase),
                                                      ],
                                          child: MaterialApp(
                                                        home: PaymentWebViewScreen(
                                                                        paymentUrl: testPaymentUrl,
                                                                        transactionId: testTransactionId,
                                                                      ),
                                                      ),
                                        ),
                            );
            }

            testWidgets('Renders screen elements correctly (AppBar and WebView)', (WidgetTester tester) async {
                    await pumpScreen(tester);
                    expect(find.text(''\u0627\u0644\u062f\u0641\u0639 \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a'), findsOneWidget);
                          expect(find.byType(WebViewWidget), findsOneWidget);
                              });

                                  testWidgets('Triggers success confirmation flow and updates status on Supabase Realtime update', (WidgetTester tester) async {
                                        await pumpScreen(tester);

                                              final topic = 'public:transactions:id=eq.42';
                                                    expect(fakeSupabase.channels.containsKey(topic), true);
                                                          final fakeChannel = fakeSupabase.channels[topic]!;
                                                                expect(fakeChannel.callback, isNotNull);

                                                                      fakeChannel.callback!(
                                                                              FakePostgresChangePayload(
                                                                                        newRecord: {'status': 'completed'},
                                                                                                ),
                                                                                                      );
                                                                                                      
                                                                                                            await tester.pumpAndSettle();
                                                                                                            
                                                                                                                  expect(find.text('\u062a\u0645\u062a \u0639\u0645\u0644\u064a\u0629 \u0627\u0644\u062f\u0641\u0639 \u0628\u0646\u062c\u0627\u062d'), findsOneWidget);
                                                                                                                        expect(find.textContaining('\u062a\u0641\u0639\u064a\u0644'), findsOneWidget);
                                                                                                                        
                                                                                                                              await tester.tap(find.text('\u0645\u0648\u0627\u0641\u0642'));
                                                                                                                                    await tester.pumpAndSettle();
                                                                                                                                        });
                                                                                                                                        
                                                                                                                                            testWidgets('Triggers failure flow on Supabase Realtime update with status "failed"', (WidgetTester tester) async {
                                                                                                                                                  await pumpScreen(tester);
                                                                                                                                                  
                                                                                                                                                        final topic = 'public:transactions:id=eq.42';
                                                                                                                                                              final fakeChannel = fakeSupabase.channels[topic]!;
                                                                                                                                                              
                                                                                                                                                                    fakeChannel.callback!(
                                                                                                                                                                            FakePostgresChangePayload(
                                                                                                                                                                                      newRecord: {'status': 'failed'},
                                                                                                                                                                                              ),
                                                                                                                                                                                                    );
                                                                                                                                                                                                    
                                                                                                                                                                                                          await tester.pumpAndSettle();
                                                                                                                                                                                                          
                                                                                                                                                                                                                expect(find.text('\u0641\u0634\u0644\u062a \u0639\u0645\u0644\u064a\u0629 \u0627\u0644\u062f\u0641\u0639'), findsOneWidget);
                                                                                                                                                                                                                      expect(find.textContaining('\u0627\u0644\u062a\u062d\u0642\u0642'), findsOneWidget);
                                                                                                                                                                                                                      
                                                                                                                                                                                                                            await tester.tap(find.text('\u0645\u0648\u0627\u0641\u0642'));
                                                                                                                                                                                                                                  await tester.pumpAndSettle();
                                                                                                                                                                                                                                      });
                                                                                                                                                                                                                                      
}    testWidgets('Triggers cancellation flow when user cancels (web navigation to cancel URL)', (WidgetTester tester) async {
      await pumpScreen(tester);

            final webViewController = _FakeWebViewController.latestInstance;
                  expect(webViewController, isNotNull);

                        final decision = await webViewController!.navigationDelegate.onNavigationRequest!(
                                NavigationRequest(
                                          url: 'https://wasla.eg/payment/cancel',
                                               isMainFrame: true,
                                             ),
                                 );

                    expect(decision, NavigationDecision.prevent);

                    await tester.pumpAndSettle();

                    expect(find.text('\u062a\u0645 \u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u062f\u0641\u0639'), findsOneWidget);
                    expect(find.textContaining('\u0625\u0644\u063a\u0627\u0621'), findsOneWidget);
            });

            testWidgets('Triggers confirmation screen when callback redirect success=true occurs', (WidgetTester tester) async {
                    await pumpScreen(tester);

                    final webViewController = _FakeWebViewController.latestInstance;
                    expect(webViewController, isNotNull);

                    final decision = await webViewController!.navigationDelegate.onNavigationRequest!(
                              NavigationRequest(
                                          url: 'https://wasla.eg/payment/callback?success=true&id=42',
                                          isMainFrame: true,
                                        ),
                            );

                    expect(decision, NavigationDecision.prevent);

                    await tester.pump();

                    expect(find.text('\u062c\u0627\u0631\u064a \u062a\u0623\u0643\u064a\u062f \u0639\u0645\u0644\u064a\u0629 \u0627\u0644\u062f\u0641\u0639...'), findsOneWidget);
            });

            testWidgets('Triggers timeout warning if payment takes too long', (WidgetTester tester) async {
                    await pumpScreen(tester);

                    await tester.pump(const Duration(minutes: 3, seconds: 1));

                    expect(find.text('\u0627\u0646\u062a\u0647\u062a \u0645\u0647\u0644\u0629 \u0627\u0644\u062f\u0641\u0639'), findsOneWidget);
            });
      });
  }

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
  }

  class _FakeWebViewController extends PlatformWebViewController {
      static _FakeWebViewController? latestInstance;
      late final NavigationDelegate navigationDelegate;

      _FakeWebViewController(super.params) : super.implementation() {
            latestInstance = this;
      }

      @override
      Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

      @override
      Future<void> setNavigationDelegate(NavigationDelegate delegate) async {
            navigationDelegate = delegate;
      }

      @override
      Future<void> loadRequest(LoadRequestParams params) async {}
  }

  class _FakeWebViewWidget extends PlatformWebViewWidget {
      _FakeWebViewWidget(super.params) : super.implementation();

      @override
      Widget build(BuildContext context) {
            return const SizedBox.shrink();
      }
  }
  
