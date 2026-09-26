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

  /// Aplica as preferências vindas da conta sem carregar permissões do outro
  /// aparelho. A permissão de notificações pertence a cada dispositivo.
  Future<void> replaceFromCloud(AppSettings settings) async {
    _settings = settings.copyWith(dailyReminderPermissionRequested: false);
    await _storage.save(_settings);
    notifyListeners();
    await reconcileDailyReminder();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_settings.themeMode == mode) return;
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _storage.save(_settings);
  }

  Future<void> setNightModeEnabled(bool enabled) =>
      _saveSettings(_settings.copyWith(nightModeEnabled: enabled));

  Future<void> setReduceBrightness(bool enabled) =>
      _saveSettings(_settings.copyWith(reduceBrightness: enabled));

  Future<void> setHighContrast(bool enabled) =>
      _saveSettings(_settings.copyWith(highContrast: enabled));

  Future<void> setReduceMotion(bool enabled) =>
      _saveSettings(_settings.copyWith(reduceMotion: enabled));

  Future<void> setTextScaleFactor(double factor) =>
      _saveSettings(_settings.copyWith(textScaleFactor: factor));

  Future<void> setPomodoroSettings({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    bool? autoStartBreak,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) => _saveSettings(
    _settings.copyWith(
      pomodoroFocusMinutes: focusMinutes,
      pomodoroShortBreakMinutes: shortBreakMinutes,
      pomodoroLongBreakMinutes: longBreakMinutes,
      pomodoroAutoStartBreak: autoStartBreak,
      pomodoroSoundEnabled: soundEnabled,
      pomodoroVibrationEnabled: vibrationEnabled,
    ),
  );

  Future<void> setCountdown({String? title, DateTime? date}) => _saveSettings(
    _settings.copyWith(countdownTitle: title, countdownDate: date),
  );

  Future<void> clearCountdown() => _saveSettings(
    _settings.copyWith(countdownTitle: null, countdownDate: null),
  );

  Future<void> reconcileDailyReminder() async {
    if (!_settings.dailyReminderEnabled) {
      await _cancelReminderSchedules(_settings);
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
      for (final time in _settings.dailyReminderTimes) {
        for (final weekday in _settings.dailyReminderWeekdays) {
          await _reminders.scheduleDailyPlanningReminder(
            hour: time.hour,
            minute: time.minute,
            weekday: weekday,
          );
        }
      }
    } catch (_) {
      // O lembrete é opcional e não pode impedir a abertura do aplicativo.
    }
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    if (_settings.dailyReminderEnabled == enabled) return;
    if (!enabled) {
      await _cancelReminderSchedules(_settings);
    }
    _settings = _settings.copyWith(dailyReminderEnabled: enabled);
    notifyListeners();
    await _storage.save(_settings);
    if (enabled) await reconcileDailyReminder();
  }

  Future<void> setDailyReminderTimes(List<DailyReminderTime> times) async {
    final normalizedTimes = times.toSet().toList()..sort();
    if (normalizedTimes.isEmpty ||
        _sameReminderTimes(normalizedTimes, _settings.dailyReminderTimes)) {
      return;
    }
    await _cancelReminderSchedules(_settings);
    _settings = _settings.copyWith(dailyReminderTimes: normalizedTimes);
    notifyListeners();
    await _storage.save(_settings);
    if (_settings.dailyReminderEnabled) await reconcileDailyReminder();
  }

  Future<void> setDailyReminderWeekdays(List<int> weekdays) async {
    final normalized =
        weekdays
            .where(
              (weekday) =>
                  weekday >= DateTime.monday && weekday <= DateTime.sunday,
            )
            .toSet()
            .toList()
          ..sort();
    if (normalized.isEmpty ||
        _sameWeekdays(normalized, _settings.dailyReminderWeekdays)) {
      return;
    }
    await _cancelReminderSchedules(_settings);
    _settings = _settings.copyWith(dailyReminderWeekdays: normalized);
    notifyListeners();
    await _storage.save(_settings);
    if (_settings.dailyReminderEnabled) await reconcileDailyReminder();
  }

  Future<void> toggleDailyReminderWeekday(int weekday) {
    final selected = _settings.dailyReminderWeekdays.contains(weekday);
    final updated = selected
        ? _settings.dailyReminderWeekdays
              .where((current) => current != weekday)
              .toList()
        : [..._settings.dailyReminderWeekdays, weekday];
    return setDailyReminderWeekdays(updated);
  }

  Future<void> toggleDailyReminderTime(DailyReminderTime time) {
    final currentTimes = _settings.dailyReminderTimes;
    final isSelected = currentTimes.contains(time);
    final updatedTimes = isSelected
        ? currentTimes.where((current) => current != time).toList()
        : [...currentTimes, time];
    return setDailyReminderTimes(updatedTimes);
  }

  /// Mantém o método para quem já configurava um único horário pelo app.
  Future<void> setDailyReminderTime(TimeOfDay time) => setDailyReminderTimes([
    DailyReminderTime(hour: time.hour, minute: time.minute),
  ]);

  static bool _sameReminderTimes(
    List<DailyReminderTime> first,
    List<DailyReminderTime> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static bool _sameWeekdays(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<void> _saveSettings(AppSettings updated) async {
    if (_settings == updated) return;
    _settings = updated;
    notifyListeners();
    await _storage.save(_settings);
  }

  Future<void> _cancelReminderSchedules(AppSettings settings) async {
    await _reminders.cancelDailyPlanningReminder();
    for (final time in settings.dailyReminderTimes) {
      for (final weekday in settings.dailyReminderWeekdays) {
        await _reminders.cancelDailyPlanningReminder(
          hour: time.hour,
          minute: time.minute,
          weekday: weekday,
        );
      }
    }
  }
}
