import '../models/study_session.dart';

class StudySessionSummary {
  const StudySessionSummary._();

  static List<StudySession> sessionsForDay(
    Iterable<StudySession> sessions,
    DateTime day,
  ) => sessions.where((session) => isSameDay(session.startedAt, day)).toList();

  static Duration totalForDay(Iterable<StudySession> sessions, DateTime day) =>
      sessionsForDay(
        sessions,
        day,
      ).fold(Duration.zero, (total, session) => total + session.duration);

  static Map<String, Duration> totalBySubjectForDay(
    Iterable<StudySession> sessions,
    DateTime day,
  ) {
    final totals = <String, Duration>{};
    for (final session in sessionsForDay(sessions, day)) {
      final subject = session.subject ?? 'Sem matéria';
      totals.update(
        subject,
        (duration) => duration + session.duration,
        ifAbsent: () => session.duration,
      );
    }
    return totals;
  }

  static bool isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
