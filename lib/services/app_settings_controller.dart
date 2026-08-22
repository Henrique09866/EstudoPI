import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import 'app_settings_storage.dart';
import 'daily_reminder_scheduler.dart';

/// Mantém preferências globais em um único lugar e atualiza a UI imediatamente.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(
    this._storage,
    this._reminders, {
    AppSettings initialSettings = const AppSettings(),
  }) : _settings = initialSettings;

  final AppSettingsStorage _storage;
  final DailyReminderScheduler _reminders;
  AppSettings _settings;
  bool _dailyReminderAvailable = true;

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  bool get dailyReminderAvailable => _dailyReminderAvailable;

  Future<void> load() async {
    _settings = await _storage.load();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_settings.themeMode == mode) return;
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _storage.save(_settings);
  }

  Future<void> reconcileDailyReminder() async {
    if (!_settings.dailyReminderEnabled) {
      await _reminders.cancelDailyPlanningReminder();
      return;
    }
    if (!_reminders.canScheduleNotifications) {
      _dailyReminderAvailable = false;
      notifyListeners();
      return;
    }
    _dailyReminderAvailable = true;

    var permissionGranted = _settings.dailyReminderPermissionGranted;
    if (!_settings.dailyReminderPermissionRequested) {
      permissionGranted = await _reminders.requestPermission();
      _settings = _settings.copyWith(
        dailyReminderPermissionRequested: true,
        dailyReminderPermissionGranted: permissionGranted,
      );
      await _storage.save(_settings);
      notifyListeners();
    }
    if (permissionGranted != true) return;
    try {
      await _reminders.scheduleDailyPlanningReminder(
        hour: _settings.dailyReminderHour,
        minute: _settings.dailyReminderMinute,
      );
    } catch (_) {
      // O lembrete é opcional e não pode impedir a abertura do aplicativo.
    }
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    if (_settings.dailyReminderEnabled == enabled) return;
    if (!enabled) {
      await _reminders.cancelDailyPlanningReminder();
    }
    _settings = _settings.copyWith(dailyReminderEnabled: enabled);
    notifyListeners();
    await _storage.save(_settings);
    if (enabled) await reconcileDailyReminder();
  }

  Future<void> setDailyReminderTime(TimeOfDay time) async {
    if (_settings.dailyReminderHour == time.hour &&
        _settings.dailyReminderMinute == time.minute) {
      return;
    }
    await _reminders.cancelDailyPlanningReminder();
    _settings = _settings.copyWith(
      dailyReminderHour: time.hour,
      dailyReminderMinute: time.minute,
    );
    notifyListeners();
    await _storage.save(_settings);
    if (_settings.dailyReminderEnabled) await reconcileDailyReminder();
  }
}
