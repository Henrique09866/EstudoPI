import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/services/notification_service.dart';
import 'package:taskflow/services/task_notification_scheduler.dart';

void main() {
  final now = DateTime(2026, 8, 21, 12);
  final taskDate = DateTime(2026, 8, 21, 20);
  final createdAt = DateTime(2026, 8, 21, 9);

  Task createTask({
    String id = 'task-1',
    DateTime? dateTime,
    ReminderOffset reminderOffset = ReminderOffset.atTime,
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      title: 'Estudar matemática',
      dateTime: dateTime ?? taskDate,
      priority: TaskPriority.medium,
      reminderOffset: reminderOffset,
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }

  group('NotificationService', () {
    test('ID determinístico da notificação', () {
      final firstId = NotificationService.notificationIdForTaskId('task-123');
      final secondId = NotificationService.notificationIdForTaskId('task-123');

      expect(firstId, secondId);
      expect(firstId, isPositive);
    });

    test('cálculo de lembrete no horário', () {
      final task = createTask();

      expect(NotificationService.notificationDateFor(task, now: now), taskDate);
    });

    test('cálculo de 10 minutos antes', () {
      final task = createTask(reminderOffset: ReminderOffset.tenMinutes);

      expect(
        NotificationService.notificationDateFor(task, now: now),
        DateTime(2026, 8, 21, 19, 50),
      );
    });

    test('cálculo de 30 minutos antes', () {
      final task = createTask(reminderOffset: ReminderOffset.thirtyMinutes);

      expect(
        NotificationService.notificationDateFor(task, now: now),
        DateTime(2026, 8, 21, 19, 30),
      );
    });

    test('cálculo de 1 hora antes', () {
      final task = createTask(reminderOffset: ReminderOffset.oneHour);

      expect(
        NotificationService.notificationDateFor(task, now: now),
        DateTime(2026, 8, 21, 19),
      );
    });

    test('tarefa passada não é agendada', () {
      final task = createTask(dateTime: DateTime(2026, 8, 21, 10));

      expect(NotificationService.notificationDateFor(task, now: now), isNull);
      expect(
        NotificationService.shouldScheduleTaskNotification(task, now: now),
        isFalse,
      );
    });

    test('lembrete cujo horário já passou não é agendado', () {
      final task = createTask(
        dateTime: DateTime(2026, 8, 21, 12, 20),
        reminderOffset: ReminderOffset.thirtyMinutes,
      );

      expect(NotificationService.notificationDateFor(task, now: now), isNull);
    });

    test('tarefa concluída não é agendada', () {
      final task = createTask(isCompleted: true);

      expect(
        NotificationService.shouldScheduleTaskNotification(task, now: now),
        isFalse,
      );
    });

    test('cancelamento', () async {
      final scheduler = FakeNotificationScheduler();

      await scheduler.cancelTaskNotification('task-1');

      expect(scheduler.cancelledTaskIds, ['task-1']);
    });

    test('reagendamento', () async {
      final scheduler = FakeNotificationScheduler();
      final task = createTask();

      await scheduler.rescheduleTaskNotification(task);

      expect(scheduler.cancelledTaskIds, ['task-1']);
      expect(scheduler.scheduledTasks, [task]);
    });
  });
}

class FakeNotificationScheduler implements TaskNotificationScheduler {
  final scheduledTasks = <Task>[];
  final cancelledTaskIds = <String>[];

  @override
  bool get canScheduleNotifications => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleTaskNotification(Task task) async {
    scheduledTasks.add(task);
  }

  @override
  Future<void> cancelTaskNotification(String taskId) async {
    cancelledTaskIds.add(taskId);
  }

  @override
  Future<void> rescheduleTaskNotification(Task task) async {
    await cancelTaskNotification(task.id);
    await scheduleTaskNotification(task);
  }

  @override
  Future<void> reconcileTaskNotifications(List<Task> tasks) async {
    for (final task in tasks) {
      await rescheduleTaskNotification(task);
    }
  }
}
