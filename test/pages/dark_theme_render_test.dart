import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/app/theme/app_theme.dart';
import 'package:taskflow/models/app_settings.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/pages/settings_page.dart';
import 'package:taskflow/services/app_settings_controller.dart';
import 'package:taskflow/services/app_settings_storage.dart';
import 'package:taskflow/services/daily_reminder_scheduler.dart';
import 'package:taskflow/pages/calendar_page.dart';
import 'package:taskflow/pages/home_page.dart';
import 'package:taskflow/pages/progress_page.dart';
import 'package:taskflow/pages/study_page.dart';
import 'package:taskflow/services/study_session_storage.dart';
import 'package:taskflow/services/task_storage.dart';

void main() {
  Widget dark(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.dark,
    home: child,
  );

  testWidgets('dark mode renderiza a Home', (tester) async {
    await tester.pumpWidget(
      dark(HomePage(initialTasks: const [], storage: _TaskStorage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estudo Pi'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Estudo Pi'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('dark mode renderiza o calendário', (tester) async {
    await tester.pumpWidget(
      dark(CalendarPage(initialTasks: const [], storage: _TaskStorage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendário'), findsOneWidget);
  });

  testWidgets('dark mode renderiza o Modo Estudo', (tester) async {
    await tester.pumpWidget(dark(StudyPage(storage: _StudyStorage())));
    await tester.pumpAndSettle();

    expect(find.text('Modo Estudo'), findsOneWidget);
  });

  testWidgets('dark mode renderiza o dashboard', (tester) async {
    await tester.pumpWidget(
      dark(const ProgressPage(tasks: [], initialSessions: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meu progresso'), findsOneWidget);
  });

  testWidgets('Configurações não gera overflow em 320px e 1440px', (
    tester,
  ) async {
    final controller = AppSettingsController(_SettingsStorage(), _Reminder());
    for (final width in [320.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(dark(SettingsPage(controller: controller)));
      await tester.pumpAndSettle();
      expect(find.text('Configurações'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

class _StudyStorage implements StudySessionStorage {
  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<int> getDailyGoalMinutes() async => 60;

  @override
  Future<List<StudySession>> getSessions() async => [];

  @override
  Future<void> saveDailyGoalMinutes(int minutes) async {}

  @override
  Future<void> saveSession(StudySession session) async {}
}

class _TaskStorage implements TaskStorage {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<Task>> getTasks() async => [];

  @override
  Future<void> saveTask(Task task) async {}

  @override
  Future<void> updateTask(Task task) async {}
}

class _SettingsStorage implements AppSettingsStorage {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {}
}

class _Reminder implements DailyReminderScheduler {
  @override
  bool get canScheduleNotifications => true;

  @override
  Future<void> cancelDailyPlanningReminder() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDailyPlanningReminder({
    required int hour,
    required int minute,
  }) async {}
}
