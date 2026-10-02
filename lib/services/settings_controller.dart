import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/polaroid_model.dart';
import '../utils/constants.dart';

/// Persisted user preferences (theme, date format, animations).
class SettingsController extends ChangeNotifier {
  SettingsController._({
    required this.themeMode,
    required this.dateFormat,
    required this.animateDeveloping,
  });

  /// Loads persisted settings, falling back to safe defaults.
  static Future<SettingsController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SettingsController._(
        themeMode: _enumValue(
          prefs.getString(PrefsKeys.themeMode),
          ThemeMode.values,
        ),
        dateFormat: _enumValue(
          prefs.getString(PrefsKeys.dateFormat),
          DateStampFormat.values,
        ),
        animateDeveloping: prefs.getBool(PrefsKeys.animateDeveloping) ?? true,
      );
    } catch (error) {
      debugPrint('[PolaroidStudio] settings load failed: $error');
      return SettingsController.defaults();
    }
  }

  /// In memory defaults (also used by tests).
  factory SettingsController.defaults() => SettingsController._(
    themeMode: ThemeMode.system,
    dateFormat: DateStampFormat.dayMonthYear,
    animateDeveloping: true,
  );

  ThemeMode themeMode;
  DateStampFormat dateFormat;
  bool animateDeveloping;

  Future<void> setThemeMode(ThemeMode value) async {
    if (themeMode == value) return;
    themeMode = value;
    notifyListeners();
    await _persist(PrefsKeys.themeMode, value.name);
  }

  Future<void> setDateFormat(DateStampFormat value) async {
    if (dateFormat == value) return;
    dateFormat = value;
    notifyListeners();
    await _persist(PrefsKeys.dateFormat, value.name);
  }

  Future<void> setAnimateDeveloping(bool value) async {
    if (animateDeveloping == value) return;
    animateDeveloping = value;
    notifyListeners();
    await _persist(PrefsKeys.animateDeveloping, value);
  }

  Future<void> _persist(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else {
        await prefs.setString(key, value.toString());
      }
    } catch (error) {
      debugPrint('[PolaroidStudio] settings persist failed: $error');
    }
  }

  static T _enumValue<T extends Enum>(String? name, List<T> values) {
    if (name != null) {
      for (final value in values) {
        if (value.name == name) return value;
      }
    }
    return values.first;
  }
}
