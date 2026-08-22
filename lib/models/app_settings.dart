import 'package:flutter/material.dart';

/// Preferências locais que não pertencem a tarefas ou sessões de estudo.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 12,
    this.dailyReminderMinute = 0,
    this.dailyReminderPermissionRequested = false,
    this.dailyReminderPermissionGranted,
  });

  final ThemeMode themeMode;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;

  /// Evita mostrar novamente o prompt do sistema depois de uma recusa.
  final bool dailyReminderPermissionRequested;
  final bool? dailyReminderPermissionGranted;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? dailyReminderPermissionRequested,
    bool? dailyReminderPermissionGranted,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      dailyReminderPermissionRequested:
          dailyReminderPermissionRequested ??
          this.dailyReminderPermissionRequested,
      dailyReminderPermissionGranted:
          dailyReminderPermissionGranted ?? this.dailyReminderPermissionGranted,
    );
  }

  Map<String, dynamic> toMap() => {
    'themeMode': themeMode.name,
    'dailyReminderEnabled': dailyReminderEnabled,
    'dailyReminderHour': dailyReminderHour,
    'dailyReminderMinute': dailyReminderMinute,
    'dailyReminderPermissionRequested': dailyReminderPermissionRequested,
    'dailyReminderPermissionGranted': dailyReminderPermissionGranted,
  };

  factory AppSettings.fromMap(Map<dynamic, dynamic> values) {
    final themeName = values['themeMode'];
    final themeMode = ThemeMode.values.where((mode) => mode.name == themeName);
    final hour = values['dailyReminderHour'];
    final minute = values['dailyReminderMinute'];
    return AppSettings(
      themeMode: themeMode.isEmpty ? ThemeMode.system : themeMode.first,
      dailyReminderEnabled: values['dailyReminderEnabled'] is bool
          ? values['dailyReminderEnabled'] as bool
          : true,
      dailyReminderHour: hour is int && hour >= 0 && hour <= 23 ? hour : 12,
      dailyReminderMinute: minute is int && minute >= 0 && minute <= 59
          ? minute
          : 0,
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
}
