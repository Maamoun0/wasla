import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Wasla Phone Formatter test', () {
    String formatPhone(String raw) {
      String digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('0')) digits = digits.substring(1);
      return '+20$digits';
    }

    expect(formatPhone('01012345678'), '+201012345678');
    expect(formatPhone('1012345678'), '+201012345678');
  });
}
