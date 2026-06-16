import 'package:flutter/material.dart';

/// نظام الألوان الكامل لمنصة وصلة
/// الفيروز المصري + الذهب المصري + الرمال الدافئة
class AppColors {
  AppColors._();

  // ── Primary: الفيروز المصري ──────────────────────────────────────
  static const Color primary50  = Color(0xFFE4F4F6);
  static const Color primary100 = Color(0xFFB8E2E6);
  static const Color primary200 = Color(0xFF74C4CC);
  static const Color primary500 = Color(0xFF0E9AA6);
  static const Color primary600 = Color(0xFF0D7A84); // ← اللون الأساسي
  static const Color primary700 = Color(0xFF0A606A);
  static const Color primary800 = Color(0xFF074650);
  static const Color primary900 = Color(0xFF032B30);

  // ── Accent: الذهب المصري ────────────────────────────────────────
  static const Color accent50  = Color(0xFFFEF5E4);
  static const Color accent100 = Color(0xFFFDE5B0);
  static const Color accent300 = Color(0xFFF7C04A);
  static const Color accent500 = Color(0xFFE89510); // ← اللون المميز
  static const Color accent600 = Color(0xFFC97C0C);
  static const Color accent800 = Color(0xFF7A4B07);

  // ── Neutrals: رمال دافئة ────────────────────────────────────────
  static const Color white      = Color(0xFFFFFFFF);
  static const Color neutral50  = Color(0xFFF9F7F3); // ← خلفية الصفحة
  static const Color neutral100 = Color(0xFFF0EDE7);
  static const Color neutral200 = Color(0xFFEAE4DA);
  static const Color neutral300 = Color(0xFFD5CEC3);
  static const Color neutral400 = Color(0xFFB0A89C);
  static const Color neutral500 = Color(0xFF8A8278);
  static const Color neutral600 = Color(0xFF6E6459);
  static const Color neutral700 = Color(0xFF4E473E);
  static const Color neutral800 = Color(0xFF302B24);
  static const Color neutral900 = Color(0xFF161210); // ← النص الرئيسي

  // ── Semantic ────────────────────────────────────────────────────
  static const Color success    = Color(0xFF16A34A);
  static const Color successBg  = Color(0xFFDCFCE7);
  static const Color error      = Color(0xFFDC2626);
  static const Color errorBg    = Color(0xFFFEE2E2);
  static const Color warning    = Color(0xFFD97706);
  static const Color warningBg  = Color(0xFFFEF3C7);
  static const Color info       = Color(0xFF0369A1);
  static const Color infoBg     = Color(0xFFE0F2FE);

  // ── Ad Status Colors ────────────────────────────────────────────
  static const Color statusActive   = Color(0xFF16A34A);
  static const Color statusPending  = Color(0xFFD97706);
  static const Color statusExpired  = Color(0xFF8A8278);
  static const Color statusRejected = Color(0xFFDC2626);
  static const Color statusSold     = Color(0xFF0369A1);

  // ── Gradient ────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary900, primary700, Color(0xFF0DA0AC)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent600, accent500, accent300],
  );
}
