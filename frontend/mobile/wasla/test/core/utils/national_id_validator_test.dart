import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/core/utils/national_id_validator.dart';

void main() {
  group('NationalIdValidator Tests', () {
    test('Empty value should return error', () {
      expect(NationalIdValidator.validate(''), 'الرقم القومي مطلوب');
      expect(NationalIdValidator.validate(null), 'الرقم القومي مطلوب');
    });

    test('Length other than 14 should return error', () {
      expect(NationalIdValidator.validate('1234567890123'), 'يجب أن يتكون الرقم القومي من 14 رقماً');
      expect(NationalIdValidator.validate('123456789012345'), 'يجب أن يتكون الرقم القومي من 14 رقماً');
    });

    test('Non-digit characters should return error', () {
      expect(NationalIdValidator.validate('2950528010123a'), 'يجب أن يحتوي الرقم القومي على أرقام فقط');
    });

    test('First digit other than 2 or 3 should return error', () {
      expect(NationalIdValidator.validate('19505280101234'), 'الرقم القومي غير صحيح (يجب أن يبدأ بـ 2 أو 3)');
      expect(NationalIdValidator.validate('49505280101234'), 'الرقم القومي غير صحيح (يجب أن يبدأ بـ 2 أو 3)');
    });

    test('Invalid month should return error', () {
      expect(NationalIdValidator.validate('29513280101234'), 'صيغة التاريخ في الرقم القومي غير صحيحة (الشهر غير صالح)');
    });

    test('Invalid day should return error', () {
      expect(NationalIdValidator.validate('29505320101234'), 'صيغة التاريخ في الرقم القومي غير صحيحة (اليوم غير صالح)');
    });

    test('Valid 20th century ID should pass', () {
      expect(NationalIdValidator.validate('29505280101234'), null);
    });

    test('Valid 21st century ID should pass', () {
      expect(NationalIdValidator.validate('30505280101234'), null);
    });

    test('Future birth date should return error', () {
      // Assuming today is 2026-06-24, future birth dates are invalid
      expect(NationalIdValidator.validate('39905280101234'), 'تاريخ الميلاد في الرقم القومي لا يمكن أن يكون في المستقبل');
    });

    test('Arabic digits and spaces normalize to the same ID the server hashes', () {
      for (final input in ['29505280101234', ' 2950 5280 101234 ', '٢٩٥٠٥٢٨٠١٠١٢٣٤', '۲۹۵۰۵۲۸۰۱۰۱۲۳۴']) {
        expect(NationalIdValidator.normalize(input), '29505280101234', reason: input);
        expect(NationalIdValidator.validate(input), isNull, reason: input);
      }
    });
  });
}
