import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';

/// Answers one request: the decoded JSON body to return.
typedef Reply = Object? Function(http.Request request);

/// A Supabase backend in memory: every request the repositories make is
/// recorded, and answered from [routes] by path (`/rest/v1/ads`,
/// `/rest/v1/rpc/search_ads`, `/functions/v1/create-ad`), or by
/// `METHOD path` when the method matters. Unknown GETs answer `[]`, other
/// unknown requests `null`.
class FakeBackend {
  FakeBackend([Map<String, Reply>? routes]) : routes = {...?routes};

  final Map<String, Reply> routes;
  final requests = <http.Request>[];

  late final SupabaseClient client = SupabaseClient(
    'http://localhost:1',
    'test-key',
    httpClient: MockClient((req) async {
      requests.add(req);
      final reply = routes['${req.method} ${req.url.path}'] ??
          routes[req.url.path] ??
          // `/storage/v1/object/ads/*`: any path under the prefix.
          routes.entries
              .where((e) => e.key.endsWith('*') && req.url.path.startsWith(e.key.substring(0, e.key.length - 1)))
              .firstOrNull
              ?.value;
      var body = reply != null ? reply(req) : (req.method == 'GET' ? const [] : null);
      var status = 200;
      if (body is Failure) {
        status = body.status;
        body = {'message': body.message, 'error': body.message, 'code': '$status'};
      }
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status,
          headers: {'content-type': 'application/json; charset=utf-8'}, request: req);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  /// Requests to [path], optionally only [method] ones.
  List<http.Request> to(String path, {String? method}) =>
      requests.where((r) => r.url.path == path && (method == null || r.method == method)).toList();

  /// The JSON body of the last [method] request to [path].
  Object? lastBody(String path, {String method = 'POST'}) => jsonDecode(to(path, method: method).last.body);
}

/// Return from a [Reply] to answer with an error status.
class Failure {
  const Failure(this.status, [this.message = 'failed']);
  final int status;
  final String message;
}

/// Where the screen under test navigated to (null until it does).
class NavProbe {
  String? location;
}

/// Taps [finder] and lets real time pass so calls that decode on an isolate
/// (Edge Functions answers) can finish, then settles the UI.
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Image caching asks path_provider for folders; tests have no plugin, so
/// answer with a temp folder.
void _stubPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => Directory.systemTemp.createTempSync('wasla_paths').path,
  );
}

/// Pumps an app made of [routes], starting at [initialLocation], backed by
/// [backend] and signed in as [userId]. Unknown locations land on a stub
/// recorded in [nav]. [settle] false: for screens that animate forever (a
/// blinking cursor). [localized]: wraps the app in EasyLocalization (with no
/// strings, so `.tr()` shows keys) for screens that read the locale.
Future<GoRouter> pumpRoutes(
  WidgetTester tester,
  List<RouteBase> routes, {
  required String initialLocation,
  required FakeBackend backend,
  String? userId = 'u1',
  NavProbe? nav,
  List<Override> overrides = const [],
  Size size = const Size(800, 2400),
  bool settle = true,
  bool localized = false,
}) async {
  _stubPathProvider();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: routes,
    errorBuilder: (_, state) {
      nav?.location = state.uri.toString();
      return Scaffold(body: Text('route:${state.uri}'));
    },
  );
  Widget app = MaterialApp.router(routerConfig: router);
  if (localized) {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(EasyLocalization.ensureInitialized);
    app = EasyLocalization(
      supportedLocales: const [Locale('ar', 'EG')],
      path: 'unused',
      assetLoader: const _NoStrings(),
      startLocale: const Locale('ar', 'EG'),
      child: app,
    );
  }
  await tester.pumpWidget(ProviderScope(
    overrides: [
      supabaseClientProvider.overrideWithValue(backend.client),
      currentUserIdProvider.overrideWith((ref) => userId),
      ...overrides,
    ],
    child: app,
  ));
  if (localized) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return router;
}

class _NoStrings extends AssetLoader {
  const _NoStrings();
  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => const {};
}

/// Pumps [screen] as the app's only route (see [pumpRoutes]).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required FakeBackend backend,
  String? userId = 'u1',
  NavProbe? nav,
  List<Override> overrides = const [],
  Size size = const Size(800, 2400),
  bool settle = true,
  bool localized = false,
}) =>
    pumpRoutes(tester, [GoRoute(path: '/test', builder: (_, __) => screen)],
        initialLocation: '/test',
        backend: backend,
        userId: userId,
        nav: nav,
        overrides: overrides,
        size: size,
        settle: settle,
        localized: localized);
