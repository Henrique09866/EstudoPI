import 'package:flutter/material.dart';

/// Preferências locais que não pertencem a tarefas ou sessões de estudo.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.nightModeEnabled = false,
    this.reduceBrightness = false,
    this.highContrast = false,
    this.reduceMotion = false,
    this.textScaleFactor = 1,
    this.pomodoroFocusMinutes = 25,
    this.pomodoroShortBreakMinutes = 5,
    this.pomodoroLongBreakMinutes = 15,
    this.pomodoroAutoStartBreak = false,
    this.pomodoroSoundEnabled = true,
    this.pomodoroVibrationEnabled = true,
    this.dailyReminderEnabled = true,
    this.dailyReminderTimes = defaultDailyReminderTimes,
    this.dailyReminderWeekdays = defaultReminderWeekdays,
    this.countdownTitle,
    this.countdownDate,
    this.dailyReminderPermissionRequested = false,
    this.dailyReminderPermissionGranted,
  });

  static const defaultDailyReminderTimes = [
    DailyReminderTime(hour: 12),
    DailyReminderTime(hour: 18),
    DailyReminderTime(hour: 21),
  ];
  static const defaultReminderWeekdays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  final ThemeMode themeMode;
  final bool nightModeEnabled;
  final bool reduceBrightness;
  final bool highContrast;
  final bool reduceMotion;
  final double textScaleFactor;
  final int pomodoroFocusMinutes;
  final int pomodoroShortBreakMinutes;
  final int pomodoroLongBreakMinutes;
  final bool pomodoroAutoStartBreak;
  final bool pomodoroSoundEnabled;
  final bool pomodoroVibrationEnabled;
  final bool dailyReminderEnabled;
  final List<DailyReminderTime> dailyReminderTimes;
  final List<int> dailyReminderWeekdays;
  final String? countdownTitle;
  final DateTime? countdownDate;

  /// Evita mostrar novamente o prompt do sistema depois de uma recusa.
  final bool dailyReminderPermissionRequested;
  final bool? dailyReminderPermissionGranted;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? nightModeEnabled,
    bool? reduceBrightness,
    bool? highContrast,
    bool? reduceMotion,
    double? textScaleFactor,
    int? pomodoroFocusMinutes,
    int? pomodoroShortBreakMinutes,
    int? pomodoroLongBreakMinutes,
    bool? pomodoroAutoStartBreak,
    bool? pomodoroSoundEnabled,
    bool? pomodoroVibrationEnabled,
    bool? dailyReminderEnabled,
    List<DailyReminderTime>? dailyReminderTimes,
    List<int>? dailyReminderWeekdays,
    Object? countdownTitle = _sentinel,
    Object? countdownDate = _sentinel,
    bool? dailyReminderPermissionRequested,
    bool? dailyReminderPermissionGranted,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      nightModeEnabled: nightModeEnabled ?? this.nightModeEnabled,
      reduceBrightness: reduceBrightness ?? this.reduceBrightness,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      pomodoroFocusMinutes: pomodoroFocusMinutes ?? this.pomodoroFocusMinutes,
      pomodoroShortBreakMinutes:
          pomodoroShortBreakMinutes ?? this.pomodoroShortBreakMinutes,
      pomodoroLongBreakMinutes:
          pomodoroLongBreakMinutes ?? this.pomodoroLongBreakMinutes,
      pomodoroAutoStartBreak:
          pomodoroAutoStartBreak ?? this.pomodoroAutoStartBreak,
      pomodoroSoundEnabled: pomodoroSoundEnabled ?? this.pomodoroSoundEnabled,
      pomodoroVibrationEnabled:
          pomodoroVibrationEnabled ?? this.pomodoroVibrationEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderTimes: dailyReminderTimes ?? this.dailyReminderTimes,
      dailyReminderWeekdays:
          dailyReminderWeekdays ?? this.dailyReminderWeekdays,
      countdownTitle: identical(countdownTitle, _sentinel)
          ? this.countdownTitle
          : countdownTitle as String?,
      countdownDate: identical(countdownDate, _sentinel)
          ? this.countdownDate
          : countdownDate as DateTime?,
      dailyReminderPermissionRequested:
          dailyReminderPermissionRequested ??
          this.dailyReminderPermissionRequested,
      dailyReminderPermissionGranted:
          dailyReminderPermissionGranted ?? this.dailyReminderPermissionGranted,
    );
  }

  Map<String, dynamic> toMap() => {
    'themeMode': themeMode.name,
    'nightModeEnabled': nightModeEnabled,
    'reduceBrightness': reduceBrightness,
    'highContrast': highContrast,
    'reduceMotion': reduceMotion,
    'textScaleFactor': textScaleFactor,
    'pomodoroFocusMinutes': pomodoroFocusMinutes,
    'pomodoroShortBreakMinutes': pomodoroShortBreakMinutes,
    'pomodoroLongBreakMinutes': pomodoroLongBreakMinutes,
    'pomodoroAutoStartBreak': pomodoroAutoStartBreak,
    'pomodoroSoundEnabled': pomodoroSoundEnabled,
    'pomodoroVibrationEnabled': pomodoroVibrationEnabled,
    'dailyReminderEnabled': dailyReminderEnabled,
    'dailyReminderTimes': dailyReminderTimes
        .map((time) => time.toMap())
        .toList(),
    'dailyReminderWeekdays': dailyReminderWeekdays,
    'countdownTitle': countdownTitle,
    'countdownDate': countdownDate?.toIso8601String(),
    'dailyReminderPermissionRequested': dailyReminderPermissionRequested,
    'dailyReminderPermissionGranted': dailyReminderPermissionGranted,
  };

  factory AppSettings.fromMap(Map<dynamic, dynamic> values) {
    final themeName = values['themeMode'];
    final themeMode = ThemeMode.values.where((mode) => mode.name == themeName);
    final reminderTimes = _reminderTimesFromMap(values);
    return AppSettings(
      themeMode: themeMode.isEmpty ? ThemeMode.system : themeMode.first,
      nightModeEnabled: values['nightModeEnabled'] is bool
          ? values['nightModeEnabled'] as bool
          : false,
      reduceBrightness: values['reduceBrightness'] is bool
          ? values['reduceBrightness'] as bool
          : false,
      highContrast: values['highContrast'] is bool
          ? values['highContrast'] as bool
          : false,
      reduceMotion: values['reduceMotion'] is bool
          ? values['reduceMotion'] as bool
          : false,
      textScaleFactor: _positiveDouble(values['textScaleFactor'], fallback: 1),
      pomodoroFocusMinutes: _positiveInt(
        values['pomodoroFocusMinutes'],
        fallback: 25,
      ),
      pomodoroShortBreakMinutes: _positiveInt(
        values['pomodoroShortBreakMinutes'],
        fallback: 5,
      ),
      pomodoroLongBreakMinutes: _positiveInt(
        values['pomodoroLongBreakMinutes'],
        fallback: 15,
      ),
      pomodoroAutoStartBreak: values['pomodoroAutoStartBreak'] is bool
          ? values['pomodoroAutoStartBreak'] as bool
          : false,
      pomodoroSoundEnabled: values['pomodoroSoundEnabled'] is bool
          ? values['pomodoroSoundEnabled'] as bool
          : true,
      pomodoroVibrationEnabled: values['pomodoroVibrationEnabled'] is bool
          ? values['pomodoroVibrationEnabled'] as bool
          : true,
      dailyReminderEnabled: values['dailyReminderEnabled'] is bool
          ? values['dailyReminderEnabled'] as bool
          : true,
      dailyReminderTimes: reminderTimes,
      dailyReminderWeekdays: _weekdaysFromMap(values['dailyReminderWeekdays']),
      countdownTitle: _optionalText(values['countdownTitle']),
      countdownDate: _dateOrNull(values['countdownDate']),
      dailyReminderPermissionRequested:
          values['dailyReminderPermissionRequested'] is bool
          ? values['dailyReminderPermissionRequested'] as bool
          : false,
      dailyReminderPermissionGranted:
          values['dailyReminderPermissionGranted'] is bool
          ? values['dailyReminderPermissionGranted'] as bool
          : null,
    );
  }

  static const _sentinel = Object();

  static int _positiveInt(Object? value, {required int fallback}) =>
      value is num && value >= 1 ? value.toInt() : fallback;

  static double _positiveDouble(Object? value, {required double fallback}) {
    if (value is! num || value < .85 || value > 1.4) return fallback;
    return value.toDouble();
  }

  static String? _optionalText(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _dateOrNull(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static List<int> _weekdaysFromMap(Object? value) {
    if (value is! Iterable) return defaultReminderWeekdays;
    final weekdays =
        value
            .whereType<num>()
            .map((weekday) => weekday.toInt())
            .where(
              (weekday) =>
                  weekday >= DateTime.monday && weekday <= DateTime.sunday,
            )
            .toSet()
            .toList()
          ..sort();
    return weekdays.isEmpty
        ? defaultReminderWeekdays
        : List.unmodifiable(weekdays);
  }

  static List<DailyReminderTime> _reminderTimesFromMap(
    Map<dynamic, dynamic> values,
  ) {
    final storedTimes = values['dailyReminderTimes'];
    if (storedTimes is Iterable) {
      final times =
          storedTimes
              .whereType<Map>()
              .map((time) => DailyReminderTime.fromMap(time))
              .whereType<DailyReminderTime>()
              .toSet()
              .toList()
            ..sort();
      if (times.isNotEmpty) return List.unmodifiable(times);
    }

    // Instalações anteriores usavam somente um horário configurável. Elas
    // continuam recebendo o aviso naquele mesmo horário após a atualização.
    final hour = values['dailyReminderHour'];
    final minute = values['dailyReminderMinute'];
    final legacyTime = DailyReminderTime.tryCreate(hour: hour, minute: minute);
    if (legacyTime == null || legacyTime == const DailyReminderTime(hour: 12)) {
      return defaultDailyReminderTimes;
    }
    return List.unmodifiable([legacyTime]);
  }
}

class DailyReminderTime implements Comparable<DailyReminderTime> {
  const DailyReminderTime({required this.hour, this.minute = 0})
    : assert(hour >= 0 && hour <= 23),
      assert(minute >= 0 && minute <= 59);

  final int hour;
  final int minute;

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, int> toMap() => {'hour': hour, 'minute': minute};

  static DailyReminderTime? tryCreate({Object? hour, Object? minute}) {
    if (hour is! int ||
        minute is! int ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return DailyReminderTime(hour: hour, minute: minute);
  }

  static DailyReminderTime? fromMap(Map<dynamic, dynamic> values) =>
      tryCreate(hour: values['hour'], minute: values['minute']);

  @override
  int compareTo(DailyReminderTime other) {
    final hourComparison = hour.compareTo(other.hour);
    return hourComparison != 0
        ? hourComparison
        : minute.compareTo(other.minute);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyReminderTime &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
