abstract class DailyReminderScheduler {
  bool get canScheduleNotifications;

  Future<bool> requestPermission();

  Future<void> scheduleDailyPlanningReminder({
    required int hour,
    required int minute,
  });

  Future<void> cancelDailyPlanningReminder();
}
