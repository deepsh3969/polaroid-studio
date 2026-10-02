import 'package:flutter/material.dart';

import 'constants.dart';

/// Convenience accessors for theming and navigation from any [BuildContext].
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  NavigatorState get navigator => Navigator.of(this);
  ScaffoldMessengerState get scaffoldMessenger => ScaffoldMessenger.of(this);

  /// Shows a lightweight status message. Never throws.
  void showSnack(String message, {bool error = false, bool success = false}) {
    final messenger = scaffoldMessenger;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, height: 1.3),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? colors.error
              : success
              ? AppPalette.success
              : AppPalette.charcoal,
          duration: AppMetrics.snackBarDuration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
  }
}

extension StringX on String {
  /// Collapses new lines and trims, used before persisting captions.
  String get singleLine => replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Capitalises the first letter when present.
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension DoubleX on double {
  /// Clamps the value and keeps it finite (guards against NaN from gestures).
  double clampSafe(double min, double max) {
    if (isNaN || isInfinite) return min;
    return clamp(min, max).toDouble();
  }

  /// Rounds to a sensible number of decimals before persisting.
  double get rounded3 => (this * 1000).roundToDouble() / 1000;
}

extension IntX on int {
  String get twoDigits => toString().padLeft(2, '0');
}
