import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import 'daily_reminder_scheduler.dart';
import 'task_notification_scheduler.dart';

class NotificationService
    implements TaskNotificationScheduler, DailyReminderScheduler {
  NotificationService._(this._plugin);

  static const String taskReminderChannelId = 'task_reminders';
  static const String taskReminderChannelName = 'Lembretes de tarefas';
  static const String taskReminderChannelDescription =
      'Notificações das tarefas agendadas';
  static const int dailyPlanningReminderId = 0;
  static const String dailyPlanningChannelId = 'daily_planning_reminder';
  static const String dailyPlanningChannelName = 'Planejamento diário';
  static const String dailyPlanningChannelDescription =
      'Lembrete diário para organizar os estudos';

  static final NotificationService instance = NotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool? _permissionGranted;

  static Future<void> init() async {
    tz.initializeTimeZones();
    await _configureLocalTimezone();
    await instance._initPlugin();
  }

  static Future<void> _configureLocalTimezone() async {
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }
  }

  Future<void> _initPlugin() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Abrir Estudo Pi',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Estudo Pi',
      appUserModelId: 'TaskFlow.Local.Reminders',
      guid: '3f4f5c2d-52a5-4f1d-8ef0-bf8f7d7e5a28',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
        windows: windowsSettings,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            taskReminderChannelId,
            taskReminderChannelName,
            description: taskReminderChannelDescription,
            importance: Importance.defaultImportance,
          ),
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            dailyPlanningChannelId,
            dailyPlanningChannelName,
            description: dailyPlanningChannelDescription,
            importance: Importance.defaultImportance,
          ),
        );
  }

  @override
  bool get canScheduleNotifications {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.windows => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      TargetPlatform.linux => false,
      TargetPlatform.fuchsia => false,
    };
  }

  @override
  Future<bool> requestPermission() async {
    if (_permissionGranted != null) {
      return _permissionGranted!;
    }

    final androidPermission = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    if (androidPermission != null) {
      _permissionGranted = androidPermission;
      return _permissionGranted!;
    }

    final iosPermission = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (iosPermission != null) {
      _permissionGranted = iosPermission;
      return _permissionGranted!;
    }

    final macPermission = await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _permissionGranted = macPermission ?? true;
    return _permissionGranted!;
  }

  @override
  Future<void> scheduleTaskNotification(Task task) async {
    if (!shouldScheduleTaskNotification(task)) {
      return;
    }

    if (!canScheduleNotifications) {
      throw const NotificationUnavailableException(
        'Lembretes agendados não estão disponíveis nesta plataforma.',
      );
    }

    final permissionGranted = await requestPermission();
    if (!permissionGranted) {
      throw const NotificationUnavailableException(
        'As notificações estão desativadas.',
      );
    }

    final scheduledDate = notificationDateFor(task);
    if (scheduledDate == null) {
      return;
    }

    await _plugin.zonedSchedule(
      id: notificationIdForTaskId(task.id),
      title: 'Estudo Pi',
      body: 'Você tem uma tarefa para fazer:\n${task.title}',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          taskReminderChannelId,
          taskReminderChannelName,
          channelDescription: taskReminderChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        windows: WindowsNotificationDetails(
          scenario: WindowsNotificationScenario.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: task.id,
    );
  }

  @override
  Future<void> cancelTaskNotification(String taskId) async {
    await _plugin.cancel(id: notificationIdForTaskId(taskId));
  }

  /// Agenda o lembrete geral, independente das tarefas cadastradas.
  @override
  Future<void> scheduleDailyPlanningReminder({
    required int hour,
    required int minute,
  }) async {
    if (!canScheduleNotifications) return;

    final scheduledDate = nextDailyPlanningOccurrence(
      hour: hour,
      minute: minute,
    );
    await _plugin.zonedSchedule(
      id: dailyPlanningReminderId,
      title: 'Estudo Pi 📚',
      body:
          'Já organizou seu dia? Adicione suas atividades e não deixe nada para trás.',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          dailyPlanningChannelId,
          dailyPlanningChannelName,
          channelDescription: dailyPlanningChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        windows: WindowsNotificationDetails(
          scenario: WindowsNotificationScenario.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily-planning-reminder',
    );
  }

  @override
  Future<void> cancelDailyPlanningReminder() =>
      _plugin.cancel(id: dailyPlanningReminderId);

  static tz.TZDateTime nextDailyPlanningOccurrence({
    required int hour,
    required int minute,
    tz.TZDateTime? now,
  }) {
    final current = now ?? tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );
    if (!next.isAfter(current)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// Versão sem timezone para testes e regras de apresentação.
  static DateTime nextDailyPlanningOccurrenceLocal({
    required int hour,
    required int minute,
    required DateTime now,
  }) {
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  @override
  Future<void> rescheduleTaskNotification(Task task) async {
    await cancelTaskNotification(task.id);
    await scheduleTaskNotification(task);
  }

  @override
  Future<void> reconcileTaskNotifications(List<Task> tasks) async {
    for (final task in tasks) {
      if (shouldScheduleTaskNotification(task)) {
        await rescheduleTaskNotification(task);
      } else {
        await cancelTaskNotification(task.id);
      }
    }
  }

  static bool shouldScheduleTaskNotification(Task task, {DateTime? now}) {
    return !task.isCompleted && notificationDateFor(task, now: now) != null;
  }

  static DateTime? notificationDateFor(Task task, {DateTime? now}) {
    final notificationDate = task.dateTime.subtract(
      task.reminderOffset.duration,
    );
    final currentTime = now ?? DateTime.now();

    if (!notificationDate.isAfter(currentTime)) {
      return null;
    }

    return notificationDate;
  }

  static int notificationIdForTaskId(String taskId) {
    const fnvPrime = 16777619;
    var hash = 2166136261;

    for (final codeUnit in taskId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }

    return hash == 0 ? 1 : hash;
  }
}
