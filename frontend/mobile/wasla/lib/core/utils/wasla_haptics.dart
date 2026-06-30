import 'package:flutter/services.dart';

class WaslaHaptics {
  /// Light tap for subtle interactions (e.g., clicking a minor button)
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium tap for standard actions (e.g., changing a filter)
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact for significant actions (e.g., deleting a post)
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Success feedback (vibration pattern for successful completion)
  static Future<void> success() async {
    // Standard sequence for success
    await HapticFeedback.vibrate();
  }

  /// Selection click (e.g., scrolling through a picker)
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }
}
