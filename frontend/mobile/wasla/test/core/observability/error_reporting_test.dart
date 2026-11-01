// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wasla/core/observability/error_reporting.dart';

void main() {
  group('scrubText', () {
    test('removes Egyptian phone numbers in any format', () {
      for (final phone in ['01012345678', '+201012345678', '0101 234 5678', '+20-101-234-5678']) {
        expect(scrubText('رقم $phone هنا'), 'رقم [number] هنا', reason: phone);
      }
    });

    test('removes emails, JWTs, bearer tokens and token parameters', () {
      expect(scrubText('user a.b+c@mail.example.com failed'), 'user [email] failed');
      expect(scrubText('jwt eyJhbGciOi.eyJzdWIiOi.sig-part_1'), 'jwt [token]');
      expect(scrubText('Authorization: Bearer abc.DEF-123'), 'Authorization: Bearer [token]');
      expect(scrubText('url?access_token=s3cr3t&x=1'), 'url?access_token=[filtered]&x=1');
      expect(scrubText('{"password": "hunter2"}'), '{"password": "[filtered]"}');
    });

    test('keeps ordinary text and short numbers', () {
      expect(scrubText('HTTP 404 at line 12'), 'HTTP 404 at line 12');
    });
  });

  test('scrubEvent strips text, reduces the user to an id and drops request details', () {
    final event = SentryEvent(
      message: SentryMessage('login failed for 01012345678'),
      exceptions: [SentryException(type: 'AuthException', value: 'no user x@y.com')],
      breadcrumbs: [Breadcrumb(message: 'GET ?token=abc', data: {'phone': '+201012345678'})],
      user: SentryUser(id: 'u1', email: 'x@y.com', ipAddress: '1.2.3.4', username: 'name'),
      request: SentryRequest(
        url: 'https://api.test/auth?phone=01012345678',
        method: 'POST',
        headers: {'Authorization': 'Bearer abc'},
        cookies: 'sb=1',
        data: {'phone': '01012345678'},
      ),
    );

    final out = scrubEvent(event);

    expect(out.message!.formatted, 'login failed for [number]');
    expect(out.exceptions!.single.value, 'no user [email]');
    expect(out.breadcrumbs!.single.message, 'GET ?token=[filtered]');
    expect(out.breadcrumbs!.single.data, {'phone': '[number]'});
    expect(out.user!.id, 'u1');
    expect([out.user!.email, out.user!.ipAddress, out.user!.username], [null, null, null]);
    expect(out.request!.url, 'https://api.test/auth');
    expect(out.request!.method, 'POST');
    expect([out.request!.headers, out.request!.cookies, out.request!.data], [isEmpty, null, null]);
  });

  test('without SENTRY_DSN the app runner is called directly', () async {
    expect(ErrorReporting.dsn, isEmpty);
    var ran = false;
    await ErrorReporting.run(() => ran = true);
    expect(ran, isTrue);
  });
}
