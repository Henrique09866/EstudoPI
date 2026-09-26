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

/// Mostra o andamento da sessão no sistema. Diferente do alarme, esse aviso
/// também funciona para o cronômetro livre, que não tem hora de término.
abstract class StudyTimerStatusNotifier {
  Future<void> showStudyTimerStatus({
    required Duration elapsed,
    required bool isPomodoro,
    required bool isBreak,
    required Duration? remaining,
    String? subject,
  });

  Future<void> cancelStudyTimerStatus();
}
