import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/supabase/function_errors.dart';

void main() {
  test("a function's refusal shows its own Arabic message, not the exception text", () {
    const e = FunctionException(status: 400, details: {'error': 'تعذّر قبول طلب التحقق بهذه البيانات.'});
    expect(functionErrorMessage(e, fallback: 'x'), 'تعذّر قبول طلب التحقق بهذه البيانات.');
  });

  test('the code of a plan-limit refusal is available to the app', () {
    const e = FunctionException(status: 403, details: {'error': 'وصلت للحد الأقصى', 'code': 'ad_limit_reached'});
    expect(functionErrorCode(e), 'ad_limit_reached');
  });

  test('network errors and bodies without a message fall back', () {
    expect(functionErrorMessage(Exception('SocketException'), fallback: 'تحقق من اتصالك'), 'تحقق من اتصالك');
    expect(functionErrorMessage(const FunctionException(status: 500, details: 'oops'), fallback: 'f'), 'f');
    expect(functionErrorMessage(const FunctionException(status: 500, details: {'error': ' '}), fallback: 'f'), 'f');
    expect(functionErrorCode(Exception('x')), isNull);
  });
}
