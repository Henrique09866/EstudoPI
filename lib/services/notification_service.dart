import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import 'daily_reminder_scheduler.dart';
import 'study_timer_alarm_scheduler.dart';
import 'task_notification_scheduler.dart';

class NotificationService
    implements
        TaskNotificationScheduler,
        DailyReminderScheduler,
        StudyTimerAlarmScheduler {
  NotificationService._(this._plugin);

  // Os IDs possuem versão para que instalações que já tinham os canais
  // antigos recebam as novas opções de alarme (Android não altera um canal
  // depois de criado).
  static const String taskReminderChannelId = 'task_alarms_v2';
  static const String taskReminderChannelName = 'Alarmes de tarefas';
  static const String taskReminderChannelDescription =
      'Alarmes das tarefas no horário programado';
  // O ID 0 foi usado até a versão com apenas um horário. Mantemos a limpeza
  // dele no cancelamento para evitar lembretes duplicados após a atualização.
  static const int dailyPlanningReminderId = 0;
  static const int _dailyPlanningReminderIdBase = 10000;
  static const String dailyPlanningChannelId = 'daily_planning_alarm_v2';
  static const String dailyPlanningChannelName = 'Alarme diário';
  static const String dailyPlanningChannelDescription =
      'Alarme diário para organizar os estudos';
  static const int studyTimerAlarmId = 1;
  static const String studyTimerChannelId = 'study_timer_alarm_v1';
  static const String studyTimerChannelName = 'Alarme do Pomodoro';
  static const String studyTimerChannelDescription =
      'Avisos do fim das sessões de foco e pausa';

  static final NotificationService instance = NotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool? _notificationPermissionGranted;

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
      defaultActionName: 'Abrir Curujão Estudos',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Curujão Estudos',
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
            importance: Importance.max,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
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
            importance: Importance.max,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            studyTimerChannelId,
            studyTimerChannelName,
            description: studyTimerChannelDescription,
            importance: Importance.max,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
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
    if (_notificationPermissionGranted == null) {
      final androidPermission = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      if (androidPermission != null) {
        _notificationPermissionGranted = androidPermission;
      } else {
        final iosPermission = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);

        if (iosPermission != null) {
          _notificationPermissionGranted = iosPermission;
        } else {
          final macPermission = await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
          _notificationPermissionGranted = macPermission ?? true;
        }
      }
    }

    if (_notificationPermissionGranted != true) return false;
    return _requestExactAlarmPermission();
  }

  /// No Android, alarmes exatos precisam de uma autorização separada a partir
  /// do Android 12. Sem ela o sistema pode entregar o aviso atrasado.
  Future<bool> _requestExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;

    final alreadyAllowed = await android.canScheduleExactNotifications();
    if (alreadyAllowed == true) return true;
    return await android.requestExactAlarmsPermission() ?? false;
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
        'Permita notificações e alarmes para receber o lembrete no horário.',
      );
    }

    final scheduledDate = notificationDateFor(task);
    if (scheduledDate == null) {
      return;
    }

    await _plugin.zonedSchedule(
      id: notificationIdForTaskId(task.id),
      title: 'Curujão Estudos',
      body: 'Você tem uma tarefa para fazer:\n${task.title}',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          taskReminderChannelId,
          taskReminderChannelName,
          channelDescription: taskReminderChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        windows: WindowsNotificationDetails(
          scenario: WindowsNotificationScenario.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
    int? weekday,
  }) async {
    if (!canScheduleNotifications) return;
    final permissionGranted = await requestPermission();
    if (!permissionGranted) {
      throw const NotificationUnavailableException(
        'Permita notificações e alarmes para receber o lembrete diário no horário.',
      );
    }

    final scheduledDate = weekday == null
        ? nextDailyPlanningOccurrence(hour: hour, minute: minute)
        : nextWeeklyPlanningOccurrence(
            hour: hour,
            minute: minute,
            weekday: weekday,
          );
    // Remove o lembrete único de versões anteriores antes de criar os novos
    // IDs por horário. Assim, a atualização não dispara dois avisos ao meio-dia.
    await _plugin.cancel(id: dailyPlanningReminderId);
    await _plugin.zonedSchedule(
      id: dailyPlanningReminderIdFor(
        hour: hour,
        minute: minute,
        weekday: weekday,
      ),
      title: 'Curujão Estudos 📚',
      body:
          'Já organizou seu dia? Adicione suas atividades e não deixe nada para trás.',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          dailyPlanningChannelId,
          dailyPlanningChannelName,
          channelDescription: dailyPlanningChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        windows: WindowsNotificationDetails(
          scenario: WindowsNotificationScenario.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: weekday == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
      payload: 'daily-planning-reminder',
    );
  }

  @override
  Future<void> cancelDailyPlanningReminder({
    int? hour,
    int? minute,
    int? weekday,
  }) async {
    if (hour != null && minute != null && weekday != null) {
      await _plugin.cancel(
        id: dailyPlanningReminderIdFor(
          hour: hour,
          minute: minute,
          weekday: weekday,
        ),
      );
      return;
    }
    await _plugin.cancel(id: dailyPlanningReminderId);
    for (final hour in [12, 18, 21]) {
      await _plugin.cancel(
        id: dailyPlanningReminderIdFor(hour: hour, minute: 0),
      );
    }
  }

  static int dailyPlanningReminderIdFor({
    required int hour,
    required int minute,
    int? weekday,
  }) => weekday == null
      ? _dailyPlanningReminderIdBase + (hour * 60) + minute
      : _dailyPlanningReminderIdBase +
            10000 +
            (weekday * 1440) +
            (hour * 60) +
            minute;

  static tz.TZDateTime nextWeeklyPlanningOccurrence({
    required int hour,
    required int minute,
    required int weekday,
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
    final daysUntil = (weekday - next.weekday + 7) % 7;
    next = next.add(Duration(days: daysUntil));
    if (!next.isAfter(current)) next = next.add(const Duration(days: 7));
    return next;
  }

  @override
  Future<void> scheduleStudyTimerAlarm({
    required DateTime scheduledAt,
    required StudyTimerAlarmKind kind,
    String? subject,
    bool sound = true,
    bool vibration = true,
  }) async {
    if (!canScheduleNotifications || !scheduledAt.isAfter(DateTime.now())) {
      return;
    }
    final permissionGranted = await requestPermission();
    if (!permissionGranted) {
      throw const NotificationUnavailableException(
        'Permita notificações e alarmes para receber o aviso do Pomodoro.',
      );
    }

    final subjectLabel = subject?.trim();
    final isFocusCompleted = kind == StudyTimerAlarmKind.focusCompleted;
    await _plugin.zonedSchedule(
      id: studyTimerAlarmId,
      title: isFocusCompleted ? 'Tempo de foco concluído' : 'Pausa concluída',
      body: isFocusCompleted
          ? subjectLabel == null || subjectLabel.isEmpty
                ? 'Seu Pomodoro terminou. É hora da pausa.'
                : 'Seu Pomodoro de $subjectLabel terminou. É hora da pausa.'
          : 'Sua pausa terminou. Pronto para o próximo foco?',
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          studyTimerChannelId,
          studyTimerChannelName,
          channelDescription: studyTimerChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          enableVibration: vibration,
          playSound: sound,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        windows: const WindowsNotificationDetails(
          scenario: WindowsNotificationScenario.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'study-timer-alarm',
    );
  }

  @override
  Future<void> cancelStudyTimerAlarm() => _plugin.cancel(id: studyTimerAlarmId);

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
