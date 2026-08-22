import '../models/task.dart';

abstract class TaskNotificationScheduler {
  bool get canScheduleNotifications;

  Future<bool> requestPermission();

  Future<void> scheduleTaskNotification(Task task);

  Future<void> cancelTaskNotification(String taskId);

  Future<void> rescheduleTaskNotification(Task task);

  Future<void> reconcileTaskNotifications(List<Task> tasks);
}

class NotificationUnavailableException implements Exception {
  const NotificationUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
