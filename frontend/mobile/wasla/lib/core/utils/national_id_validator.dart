class NationalIdValidator {
  /// Removes whitespace and maps Arabic digits (٠-٩, ۰-۹) to ASCII, the same
  /// way submit-kyc-request does before computing the HMAC.
  static String normalize(String value) {
    final noSpaces = value.replaceAll(RegExp(r'\s+'), '');
    return String.fromCharCodes(noSpaces.runes.map((c) {
      if (c >= 0x0660 && c <= 0x0669) return c - 0x0660 + 0x30;
      if (c >= 0x06F0 && c <= 0x06F9) return c - 0x06F0 + 0x30;
      return c;
    }));
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الرقم القومي مطلوب';
    }
    
    final id = normalize(value);
    
    if (id.length != 14) {
      return 'يجب أن يتكون الرقم القومي من 14 رقماً';
    }
    
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      return 'يجب أن يحتوي الرقم القومي على أرقام فقط';
    }
    
    final firstDigit = id[0];
    if (firstDigit != '2' && firstDigit != '3') {
      return 'الرقم القومي غير صحيح (يجب أن يبدأ بـ 2 أو 3)';
    }

    final yyStr = id.substring(1, 3);
    final mmStr = id.substring(3, 5);
    final ddStr = id.substring(5, 7);

    final yy = int.tryParse(yyStr);
    final mm = int.tryParse(mmStr);
    final dd = int.tryParse(ddStr);

    if (yy == null || mm == null || dd == null) {
      return 'تاريخ الميلاد في الرقم القومي غير صالح';
    }

    if (mm < 1 || mm > 12) {
      return 'صيغة التاريخ في الرقم القومي غير صحيحة (الشهر غير صالح)';
    }

    if (dd < 1 || dd > 31) {
      return 'صيغة التاريخ في الرقم القومي غير صحيحة (اليوم غير صالح)';
    }

    final birthYear = (firstDigit == '2' ? 1900 : 2000) + yy;
    
    try {
      final birthDate = DateTime(birthYear, mm, dd);
      if (birthDate.year != birthYear || birthDate.month != mm || birthDate.day != dd) {
        return 'تاريخ الميلاد في الرقم القومي غير صالح';
      }
      if (birthDate.isAfter(DateTime.now())) {
        return 'تاريخ الميلاد في الرقم القومي لا يمكن أن يكون في المستقبل';
      }
    } catch (_) {
      return 'تاريخ الميلاد في الرقم القومي غير صالح';
    }

    return null;
  }
}
