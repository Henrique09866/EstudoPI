abstract class DailyReminderScheduler {
  bool get canScheduleNotifications;

  Future<bool> requestPermission();

  Future<void> scheduleDailyPlanningReminder({
    required int hour,
    required int minute,
    int? weekday,
  });

  Future<void> cancelDailyPlanningReminder({
    int? hour,
    int? minute,
    int? weekday,
  });
}
