import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/app_settings.dart';
import 'package:taskflow/services/app_settings_controller.dart';
import 'package:taskflow/services/app_settings_storage.dart';
import 'package:taskflow/services/daily_reminder_scheduler.dart';
import 'package:taskflow/services/notification_service.dart';

void main() {
  group('AppSettingsController', () {
    test('padrões usam sistema e lembrete ao meio-dia ativado', () {
      const settings = AppSettings();

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.dailyReminderEnabled, isTrue);
      expect(settings.dailyReminderHour, 12);
      expect(settings.dailyReminderMinute, 0);
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
      expect(scheduler.scheduled, [const TimeOfDay(hour: 12, minute: 0)]);
      await controller.setDailyReminderEnabled(false);
      expect(scheduler.cancelCount, 1);
    });

    test(
      'alterar horário cancela e reagenda, persistindo a configuração',
      () async {
        final storage = _MemorySettings();
        final scheduler = _FakeReminder();
        final controller = AppSettingsController(storage, scheduler);
        await controller.reconcileDailyReminder();
        await controller.setDailyReminderTime(
          const TimeOfDay(hour: 18, minute: 30),
        );

        expect(scheduler.cancelCount, 1);
        expect(scheduler.scheduled.last, const TimeOfDay(hour: 18, minute: 30));
        expect((await storage.load()).dailyReminderHour, 18);
        expect((await storage.load()).dailyReminderMinute, 30);
      },
    );

    test('ID diário não colide com IDs derivados de tarefas', () {
      expect(NotificationService.dailyPlanningReminderId, 0);
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
  Future<void> cancelDailyPlanningReminder() async {
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
  }) async {
    scheduled.add(TimeOfDay(hour: hour, minute: minute));
  }
}
