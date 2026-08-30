/// Agenda o aviso que encerra uma etapa do Pomodoro.
///
/// A implementação de produção usa uma notificação local exata para que o
/// aviso continue funcionando mesmo quando o aplicativo estiver em segundo
/// plano.
enum StudyTimerAlarmKind { focusCompleted, breakCompleted }

abstract class StudyTimerAlarmScheduler {
  bool get canScheduleNotifications;

  Future<void> scheduleStudyTimerAlarm({
    required DateTime scheduledAt,
    required StudyTimerAlarmKind kind,
    String? subject,
    bool sound = true,
    bool vibration = true,
  });

  Future<void> cancelStudyTimerAlarm();
}
