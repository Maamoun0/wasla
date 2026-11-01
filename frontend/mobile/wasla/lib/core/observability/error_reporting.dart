import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash reporting (🟡17). Sentry runs only when `SENTRY_DSN` is passed with
/// `--dart-define`; without it the app starts exactly as before. Nothing
/// personal leaves the device: no default PII, and [scrubEvent] removes phone
/// numbers, emails and tokens from every text field of an event.
class ErrorReporting {
  static const dsn = String.fromEnvironment('SENTRY_DSN');
  static const environment = String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production');

  static Future<void> run(FutureOr<void> Function() appRunner) async {
    if (dsn.isEmpty) {
      await appRunner();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = environment;
        options.sendDefaultPii = false;
        options.attachScreenshot = false;
        options.tracesSampleRate = 0;
        options.beforeSend = (event, hint) => scrubEvent(event);
        options.beforeBreadcrumb = (crumb, hint) => crumb == null ? null : scrubBreadcrumb(crumb);
      },
      appRunner: appRunner,
    );
  }

  static Future<void> capture(Object error, StackTrace stack) async {
    if (dsn.isEmpty) return;
    await Sentry.captureException(error, stackTrace: stack);
  }
}

final _patterns = <(RegExp, String Function(Match))>[
  (RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), (_) => '[token]'),
  (RegExp(r'(Bearer\s+)[\w.~+/-]+=*', caseSensitive: false), (m) => '${m[1]}[token]'),
  (
    RegExp(r'''((?:access_token|refresh_token|token|apikey|api_key|password|secret|otp)["']?\s*[:=]\s*["']?)[^\s"'&,}]+''',
        caseSensitive: false),
    (m) => '${m[1]}[filtered]',
  ),
  (RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'), (_) => '[email]'),
  // Phone numbers and national IDs: a run of 9+ digits, spaces or dashes allowed.
  (RegExp(r'\+?\d[\d\s-]{7,}\d'), (_) => '[number]'),
];

/// Removes phone numbers, emails and tokens from [text].
String scrubText(String text) {
  var out = text;
  for (final (re, replace) in _patterns) {
    out = out.replaceAllMapped(re, replace);
  }
  return out;
}

Map<String, dynamic> _scrubMap(Map<String, dynamic> map) =>
    map.map((k, v) => MapEntry(k, _scrubValue(v)));

Object? _scrubValue(Object? value) {
  if (value is String) return scrubText(value);
  if (value is Map) return value.map((k, v) => MapEntry(k, _scrubValue(v)));
  if (value is List) return value.map(_scrubValue).toList();
  return value;
}

Breadcrumb scrubBreadcrumb(Breadcrumb crumb) {
  if (crumb.message != null) crumb.message = scrubText(crumb.message!);
  if (crumb.data != null) crumb.data = _scrubMap(crumb.data!);
  return crumb;
}

/// The `beforeSend` filter: text fields scrubbed, the user reduced to an id,
/// and request headers, cookies, bodies and query strings dropped.
SentryEvent scrubEvent(SentryEvent event) {
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(scrubText(message.formatted),
        template: message.template == null ? null : scrubText(message.template!));
  }
  for (final e in event.exceptions ?? const <SentryException>[]) {
    if (e.value != null) e.value = scrubText(e.value!);
  }
  event.breadcrumbs?.forEach(scrubBreadcrumb);
  // ignore: deprecated_member_use
  if (event.extra != null) event.extra = _scrubMap(event.extra!);
  event.tags = event.tags?.map((k, v) => MapEntry(k, scrubText(v)));
  if (event.user != null) event.user = SentryUser(id: event.user!.id);
  final request = event.request;
  if (request != null) {
    event.request = SentryRequest(
      url: request.url == null ? null : scrubText(request.url!.split('?').first),
      method: request.method,
    );
  }
  return event;
}
