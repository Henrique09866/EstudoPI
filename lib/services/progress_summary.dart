import '../models/study_session.dart';
import '../models/task.dart';

enum ProgressPeriod { today, last7Days, last30Days }

extension ProgressPeriodLabel on ProgressPeriod {
  String get label => switch (this) {
    ProgressPeriod.today => 'Hoje',
    ProgressPeriod.last7Days => '7 dias',
    ProgressPeriod.last30Days => '30 dias',
  };
}

class ProgressSubjectEntry {
  const ProgressSubjectEntry({required this.subject, required this.duration});

  final String subject;
  final Duration duration;
}

class ProgressSummary {
  const ProgressSummary({
    required this.period,
    required this.studyDuration,
    required this.completedTasks,
    required this.completedOnTimeTasks,
    required this.completedLateTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.relevantTasks,
    required this.studyDays,
    required this.subjects,
  });

  final ProgressPeriod period;
  final Duration studyDuration;
  final int completedTasks;
  final int completedOnTimeTasks;
  final int completedLateTasks;
  final int pendingTasks;
  final int overdueTasks;
  final int relevantTasks;
  final int studyDays;
  final List<ProgressSubjectEntry> subjects;

  double get completionRate =>
      relevantTasks == 0 ? 0 : completedTasks / relevantTasks;

  bool get hasData => studyDuration > Duration.zero || relevantTasks > 0;
}

class ProgressSummaryService {
  const ProgressSummaryService();

  ProgressSummary calculate({
    required Iterable<Task> tasks,
    required Iterable<StudySession> sessions,
    required ProgressPeriod period,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final range = _rangeFor(period, referenceNow);
    final periodSessions = sessions
        .where((session) => range.contains(session.startedAt))
        .toList();
    final studyDuration = periodSessions.fold(
      Duration.zero,
      (total, session) => total + session.duration,
    );
    final subjectTotals = <String, Duration>{};
    for (final session in periodSessions) {
      final subject = session.subject?.trim().isNotEmpty == true
          ? session.subject!.trim()
          : 'Sem matéria';
      subjectTotals.update(
        subject,
        (duration) => duration + session.duration,
        ifAbsent: () => session.duration,
      );
    }
    final subjectEntries =
        subjectTotals.entries
            .map(
              (entry) => ProgressSubjectEntry(
                subject: entry.key,
                duration: entry.value,
              ),
            )
            .toList()
          ..sort((first, second) {
            final durationOrder = second.duration.compareTo(first.duration);
            return durationOrder != 0
                ? durationOrder
                : first.subject.compareTo(second.subject);
          });

    final taskList = tasks.toList();
    final completed = taskList.where(
      (task) =>
          task.isCompleted &&
          task.completedAt != null &&
          range.contains(task.completedAt!),
    );
    final completedOnTime = completed.where(
      (task) => !task.completedAt!.isAfter(task.dateTime),
    );
    final completedLate = completed.where(
      (task) => task.completedAt!.isAfter(task.dateTime),
    );
    final pending = taskList.where(
      (task) => task.isPending && range.contains(task.dateTime),
    );
    final overdue = taskList.where(
      (task) =>
          task.isPending &&
          task.dateTime.isBefore(referenceNow) &&
          range.contains(task.dateTime),
    );
    final relevant = taskList.where(
      (task) =>
          range.contains(task.dateTime) ||
          (task.completedAt != null && range.contains(task.completedAt!)),
    );
    final studyDays = periodSessions
        .map(
          (session) => DateTime(
            session.startedAt.year,
            session.startedAt.month,
            session.startedAt.day,
          ),
        )
        .toSet()
        .length;

    return ProgressSummary(
      period: period,
      studyDuration: studyDuration,
      completedTasks: completed.length,
      completedOnTimeTasks: completedOnTime.length,
      completedLateTasks: completedLate.length,
      pendingTasks: pending.length,
      overdueTasks: overdue.length,
      relevantTasks: relevant.length,
      studyDays: studyDays,
      subjects: List.unmodifiable(subjectEntries),
    );
  }

  _ProgressDateRange _rangeFor(ProgressPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final daysBack = switch (period) {
      ProgressPeriod.today => 0,
      ProgressPeriod.last7Days => 6,
      ProgressPeriod.last30Days => 29,
    };
    return _ProgressDateRange(
      start: today.subtract(Duration(days: daysBack)),
      endExclusive: today.add(const Duration(days: 1)),
    );
  }
}

class _ProgressDateRange {
  const _ProgressDateRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);
}
