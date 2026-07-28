import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing app preferences. Persisted in SharedPreferences and exposed
/// as a [ValueNotifier] so widgets can reactively rebuild on change.
class SettingsService extends ValueNotifier<AppSettings> {
  SettingsService._() : super(const AppSettings()) {
    _load();
  }

  static final SettingsService instance = SettingsService._();

  static const _kThemeMode = 'theme_mode';
  static const _kDefaultReminderHour = 'default_reminder_hour';
  static const _kDefaultReminderMinute = 'default_reminder_minute';
  static const _kShowWeekNumbers = 'show_week_numbers';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_kThemeMode) ?? 'system';
    final hour = prefs.getInt(_kDefaultReminderHour) ?? 9;
    final minute = prefs.getInt(_kDefaultReminderMinute) ?? 0;
    final showWeekNumbers = prefs.getBool(_kShowWeekNumbers) ?? false;
    value = AppSettings(
      themeMode: _decodeThemeMode(mode),
      defaultReminderHour: hour,
      defaultReminderMinute: minute,
      showWeekNumbers: showWeekNumbers,
    );
  }

  ThemeMode _decodeThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _encodeThemeMode(mode));
    value = value.copyWith(themeMode: mode);
  }

  Future<void> setDefaultReminder({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDefaultReminderHour, hour);
    await prefs.setInt(_kDefaultReminderMinute, minute);
    value = value.copyWith(
      defaultReminderHour: hour,
      defaultReminderMinute: minute,
    );
  }

  Future<void> setShowWeekNumbers(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowWeekNumbers, value);
    notifyListeners(); // direct call — no copyWith needed for a bool
  }
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultReminderHour = 9,
    this.defaultReminderMinute = 0,
    this.showWeekNumbers = false,
  });

  final ThemeMode themeMode;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final bool showWeekNumbers;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? defaultReminderHour,
    int? defaultReminderMinute,
    bool? showWeekNumbers,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute: defaultReminderMinute ?? this.defaultReminderMinute,
      showWeekNumbers: showWeekNumbers ?? this.showWeekNumbers,
    );
  }
}