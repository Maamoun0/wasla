import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/core/utils/national_id_validator.dart';

void main() {
  group('Egyptian National ID Validator Tests', () {
    test('Empty or null value returns error', () {
      expect(NationalIdValidator.validate(null), 'الرقم القومي مطلوب');
      expect(NationalIdValidator.validate(''), 'الرقم القومي مطلوب');
      expect(NationalIdValidator.validate('   '), 'الرقم القومي مطلوب');
    });

    test('13 digits should be rejected', () {
      // 13 digits
      expect(NationalIdValidator.validate('2950528010123'), 'يجب أن يتكون الرقم القومي من 14 رقماً');
    });

    test('15 digits should be rejected', () {
      // 15 digits
      expect(NationalIdValidator.validate('295052801012345'), 'يجب أن يتكون الرقم القومي من 14 رقماً');
    });

    test('Non-numeric characters should be rejected', () {
      expect(NationalIdValidator.validate('29505280a01234'), 'يجب أن يحتوي الرقم القومي على أرقام فقط');
    });

    test('First digit other than 2 or 3 should be rejected', () {
      // Starts with 1
      expect(NationalIdValidator.validate('19505280101234'), 'الرقم القومي غير صحيح (يجب أن يبدأ بـ 2 أو 3)');
      // Starts with 4
      expect(NationalIdValidator.validate('49505280101234'), 'الرقم القومي غير صحيح (يجب أن يبدأ بـ 2 أو 3)');
    });

    test('Invalid date segments should be rejected', () {
      // Month 13
      expect(NationalIdValidator.validate('29513280101234'), 'صيغة التاريخ في الرقم القومي غير صحيحة (الشهر غير صالح)');
      // Day 32
      expect(NationalIdValidator.validate('29505320101234'), 'صيغة التاريخ في الرقم القومي غير صحيحة (اليوم غير صالح)');
      // Day 30 in February
      expect(NationalIdValidator.validate('29502300101234'), 'تاريخ الميلاد في الرقم القومي غير صالح');
    });

    test('Future birthdate should be rejected', () {
      // E.g., Born in 2099 month 12 day 31
      expect(NationalIdValidator.validate('39912310101234'), 'تاريخ الميلاد في الرقم القومي لا يمكن أن يكون في المستقبل');
    });

    test('Valid 20th century ID (Starts with 2) should be accepted', () {
      // Valid ID: born 1995-05-28
      expect(NationalIdValidator.validate('29505280101234'), null);
    });

    test('Valid 21st century ID (Starts with 3) should be accepted', () {
      // Valid ID: born 2004-11-12
      expect(NationalIdValidator.validate('30411120101234'), null);
    });
  });
}
