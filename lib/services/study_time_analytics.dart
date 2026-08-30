import '../models/study_session.dart';

enum StudyChartPeriod { today, last7Days, last30Days }

extension StudyChartPeriodLabel on StudyChartPeriod {
  String get label => switch (this) {
    StudyChartPeriod.today => 'Hoje',
    StudyChartPeriod.last7Days => '7 dias',
    StudyChartPeriod.last30Days => '30 dias',
  };
}

class StudySubjectTotal {
  const StudySubjectTotal({required this.subject, required this.duration});

  final String subject;
  final Duration duration;
}

/// Calcula os dados exclusivos da Área de estudos, sem misturá-los às
/// métricas de tarefas do painel de progresso.
class StudyTimeAnalytics {
  const StudyTimeAnalytics._();

  static List<StudySubjectTotal> bySubject({
    required Iterable<StudySession> sessions,
    required StudyChartPeriod period,
    String? studyPlan,
    DateTime? now,
  }) {
    final range = _rangeFor(period, now ?? DateTime.now());
    final totals = <String, Duration>{};

    for (final session in sessions) {
      if (!range.contains(session.startedAt) ||
          !_hasStudyPlan(session, studyPlan)) {
        continue;
      }
      final subject = session.subject?.trim().isNotEmpty == true
          ? session.subject!.trim()
          : 'Sem matéria';
      totals.update(
        subject,
        (duration) => duration + session.duration,
        ifAbsent: () => session.duration,
      );
    }

    final entries =
        totals.entries
            .map(
              (entry) =>
                  StudySubjectTotal(subject: entry.key, duration: entry.value),
            )
            .toList()
          ..sort((first, second) {
            final durationOrder = second.duration.compareTo(first.duration);
            return durationOrder != 0
                ? durationOrder
                : first.subject.compareTo(second.subject);
          });
    return List.unmodifiable(entries);
  }

  static Duration total(Iterable<StudySubjectTotal> subjects) => subjects.fold(
    Duration.zero,
    (duration, subject) => duration + subject.duration,
  );

  static List<String> availableStudyPlans(Iterable<StudySession> sessions) {
    final plans =
        sessions
            .map((session) => session.studyPlan?.trim())
            .whereType<String>()
            .where((plan) => plan.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return List.unmodifiable(plans);
  }

  static bool _hasStudyPlan(StudySession session, String? requestedPlan) {
    if (requestedPlan == null) return true;
    return session.studyPlan?.trim() == requestedPlan;
  }

  static _StudyDateRange _rangeFor(StudyChartPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final daysBack = switch (period) {
      StudyChartPeriod.today => 0,
      StudyChartPeriod.last7Days => 6,
      StudyChartPeriod.last30Days => 29,
    };
    return _StudyDateRange(
      start: today.subtract(Duration(days: daysBack)),
      endExclusive: today.add(const Duration(days: 1)),
    );
  }
}

class _StudyDateRange {
  const _StudyDateRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);
}
