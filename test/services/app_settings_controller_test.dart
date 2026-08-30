import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/app_settings.dart';
import 'package:taskflow/services/app_settings_controller.dart';
import 'package:taskflow/services/app_settings_storage.dart';
import 'package:taskflow/services/daily_reminder_scheduler.dart';
import 'package:taskflow/services/notification_service.dart';

void main() {
  group('AppSettingsController', () {
    test('padrões usam sistema e lembretes em três horários ativados', () {
      const settings = AppSettings();

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.dailyReminderEnabled, isTrue);
      expect(settings.dailyReminderTimes, const [
        DailyReminderTime(hour: 12),
        DailyReminderTime(hour: 18),
        DailyReminderTime(hour: 21),
      ]);
    });

    test('configuração antiga com um horário é migrada sem perder o aviso', () {
      final settings = AppSettings.fromMap({
        'dailyReminderHour': 18,
        'dailyReminderMinute': 30,
      });

      expect(settings.dailyReminderTimes, const [
        DailyReminderTime(hour: 18, minute: 30),
      ]);
    });

    test('horário padrão antigo passa a incluir 18h e 21h', () {
      final settings = AppSettings.fromMap({
        'dailyReminderHour': 12,
        'dailyReminderMinute': 0,
      });

      expect(
        settings.dailyReminderTimes,
        AppSettings.defaultDailyReminderTimes,
      );
    });

    test('seleciona claro, escuro e volta ao sistema', () async {
      final controller = AppSettingsController(
        _MemorySettings(),
        _FakeReminder(),
      );

      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, ThemeMode.light);
      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      await controller.setThemeMode(ThemeMode.system);
      expect(controller.themeMode, ThemeMode.system);
    });

    test('preferência de tema persiste e é carregada no início', () async {
      final storage = _MemorySettings(
        const AppSettings(themeMode: ThemeMode.dark),
      );
      final first = AppSettingsController(storage, _FakeReminder());
      await first.load();
      expect(first.themeMode, ThemeMode.dark);

      await first.setThemeMode(ThemeMode.light);
      final restarted = AppSettingsController(storage, _FakeReminder());
      await restarted.load();
      expect(restarted.themeMode, ThemeMode.light);
    });

    test(
      'salva preferências Corujão, Pomodoro, acessibilidade e contagem',
      () async {
        final storage = _MemorySettings();
        final controller = AppSettingsController(storage, _FakeReminder());

        await controller.setNightModeEnabled(true);
        await controller.setReduceBrightness(true);
        await controller.setHighContrast(true);
        await controller.setReduceMotion(true);
        await controller.setTextScaleFactor(1.15);
        await controller.setPomodoroSettings(
          focusMinutes: 45,
          shortBreakMinutes: 10,
          longBreakMinutes: 20,
          autoStartBreak: true,
          soundEnabled: false,
          vibrationEnabled: false,
        );
        await controller.setCountdown(
          title: 'ENEM 2027',
          date: DateTime(2027, 11, 7),
        );

        final saved = await storage.load();
        expect(saved.nightModeEnabled, isTrue);
        expect(saved.reduceBrightness, isTrue);
        expect(saved.highContrast, isTrue);
        expect(saved.reduceMotion, isTrue);
        expect(saved.textScaleFactor, 1.15);
        expect(saved.pomodoroFocusMinutes, 45);
        expect(saved.pomodoroShortBreakMinutes, 10);
        expect(saved.pomodoroLongBreakMinutes, 20);
        expect(saved.pomodoroAutoStartBreak, isTrue);
        expect(saved.pomodoroSoundEnabled, isFalse);
        expect(saved.pomodoroVibrationEnabled, isFalse);
        expect(saved.countdownTitle, 'ENEM 2027');
        expect(saved.countdownDate, DateTime(2027, 11, 7));
      },
    );

    test('antes do meio-dia agenda para hoje', () {
      expect(
        NotificationService.nextDailyPlanningOccurrenceLocal(
          hour: 12,
          minute: 0,
          now: DateTime(2026, 8, 22, 11),
        ),
        DateTime(2026, 8, 22, 12),
      );
    });

    test('depois do meio-dia agenda para amanhã', () {
      expect(
        NotificationService.nextDailyPlanningOccurrenceLocal(
          hour: 12,
          minute: 0,
          now: DateTime(2026, 8, 22, 14),
        ),
        DateTime(2026, 8, 23, 12),
      );
    });

    test('ativar agenda e desativar cancela', () async {
      final scheduler = _FakeReminder();
      final controller = AppSettingsController(
        _MemorySettings(const AppSettings(dailyReminderEnabled: false)),
        scheduler,
      );
      await controller.load();

      await controller.setDailyReminderEnabled(true);
      expect(scheduler.scheduled, hasLength(21));
      expect(
        scheduler.scheduled.where(
          (time) => time == const TimeOfDay(hour: 12, minute: 0),
        ),
        hasLength(7),
      );
      await controller.setDailyReminderEnabled(false);
      expect(scheduler.cancelCount, 22);
    });

    test('altera os horários, cancela e reageenda as notificações', () async {
      final storage = _MemorySettings();
      final scheduler = _FakeReminder();
      final controller = AppSettingsController(storage, scheduler);
      await controller.reconcileDailyReminder();
      await controller.setDailyReminderTime(
        const TimeOfDay(hour: 18, minute: 30),
      );

      expect(scheduler.cancelCount, 22);
      expect(scheduler.scheduled.last, const TimeOfDay(hour: 18, minute: 30));
      expect((await storage.load()).dailyReminderTimes, const [
        DailyReminderTime(hour: 18, minute: 30),
      ]);
    });

    test('permite incluir e remover os horários de 18h e 21h', () async {
      final scheduler = _FakeReminder();
      final controller = AppSettingsController(
        _MemorySettings(
          const AppSettings(dailyReminderTimes: [DailyReminderTime(hour: 12)]),
        ),
        scheduler,
      );
      await controller.load();

      await controller.toggleDailyReminderTime(
        const DailyReminderTime(hour: 18),
      );
      await controller.toggleDailyReminderTime(
        const DailyReminderTime(hour: 21),
      );

      expect(controller.settings.dailyReminderTimes, const [
        DailyReminderTime(hour: 12),
        DailyReminderTime(hour: 18),
        DailyReminderTime(hour: 21),
      ]);
      expect(
        scheduler.scheduled,
        containsAll(const [
          TimeOfDay(hour: 12, minute: 0),
          TimeOfDay(hour: 18, minute: 0),
          TimeOfDay(hour: 21, minute: 0),
        ]),
      );
    });

    test('ID diário não colide com IDs derivados de tarefas', () {
      expect(NotificationService.dailyPlanningReminderId, 0);
      expect(
        NotificationService.dailyPlanningReminderIdFor(hour: 18, minute: 0),
        isNot(NotificationService.dailyPlanningReminderId),
      );
      expect(NotificationService.notificationIdForTaskId('task-1'), isNot(0));
      expect(NotificationService.notificationIdForTaskId('task-2'), isNot(0));
    });

    test('permissão negada não quebra e não agenda', () async {
      final scheduler = _FakeReminder(permissionGranted: false);
      final controller = AppSettingsController(_MemorySettings(), scheduler);

      await controller.reconcileDailyReminder();

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.requestCount, 1);
    });
  });
}

class _MemorySettings implements AppSettingsStorage {
  _MemorySettings([this.value = const AppSettings()]);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }
}

class _FakeReminder implements DailyReminderScheduler {
  _FakeReminder({this.permissionGranted = true});

  final bool permissionGranted;
  final scheduled = <TimeOfDay>[];
  var cancelCount = 0;
  var requestCount = 0;

  @override
  bool get canScheduleNotifications => true;

  @override
  Future<void> cancelDailyPlanningReminder({
    int? hour,
    int? minute,
    int? weekday,
  }) async {
    cancelCount++;
  }

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleDailyPlanningReminder({
    required int hour,
    required int minute,
    int? weekday,
  }) async {
    scheduled.add(TimeOfDay(hour: hour, minute: minute));
  }
}
