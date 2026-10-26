import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/features/auth/providers/auth_provider.dart';

void main() {
  group('otpRateLimitFrom', () {
    test('reads the wait time from Auth\'s per-number limit (as returned by local Auth)', () {
      const e = AuthException(
        'For security purposes, you can only request this after 37 seconds.',
        statusCode: '429',
        code: 'over_sms_send_rate_limit',
      );
      final limited = otpRateLimitFrom(e);
      expect(limited, isNotNull);
      expect(limited!.retryAfter, const Duration(seconds: 37));
      expect(limited.message, contains('37'));
    });

    test('a project-wide limit without a wait time still maps to a clear message', () {
      final limited = otpRateLimitFrom(const AuthException('SMS rate limit exceeded', statusCode: '429'));
      expect(limited!.retryAfter, isNull);
      expect(limited.message, contains('لاحقاً'));
    });

    test('other errors are not rate limits', () {
      expect(otpRateLimitFrom(const AuthException('Invalid phone number', statusCode: '400')), isNull);
    });
  });
}
