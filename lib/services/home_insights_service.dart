import '../models/study_session.dart';
import '../models/task.dart';
import 'study_time_analytics.dart';

class WeeklyStudySummary {
  const WeeklyStudySummary({
    required this.duration,
    required this.subjects,
    required this.overdueTasks,
  });

  final Duration duration;
  final List<StudySubjectTotal> subjects;
  final int overdueTasks;
}

/// Reúne os dados do painel inicial sem alterar tarefas ou sessões.
class HomeInsightsService {
  const HomeInsightsService();

  int studyStreak(Iterable<StudySession> sessions, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final studiedDays = sessions
        .where((session) => session.duration > Duration.zero)
        .map(
          (session) => DateTime(
            session.startedAt.year,
            session.startedAt.month,
            session.startedAt.day,
          ),
        )
        .toSet();
    var currentDay = DateTime(reference.year, reference.month, reference.day);
    var streak = 0;
    while (studiedDays.contains(currentDay)) {
      streak++;
      currentDay = currentDay.subtract(const Duration(days: 1));
    }
    return streak;
  }

  WeeklyStudySummary weeklySummary({
    required Iterable<StudySession> sessions,
    required Iterable<Task> tasks,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final firstDay = today.subtract(const Duration(days: 6));
    final totals = <String, Duration>{};
    for (final session in sessions) {
      if (session.startedAt.isBefore(firstDay) ||
          session.startedAt.isAfter(reference)) {
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
    final subjects =
        totals.entries
            .map(
              (entry) =>
                  StudySubjectTotal(subject: entry.key, duration: entry.value),
            )
            .toList()
          ..sort((first, second) => second.duration.compareTo(first.duration));
    return WeeklyStudySummary(
      duration: subjects.fold(
        Duration.zero,
        (total, subject) => total + subject.duration,
      ),
      subjects: List.unmodifiable(subjects),
      overdueTasks: tasks
          .where((task) => task.isPending && task.dateTime.isBefore(reference))
          .length,
    );
  }

  List<Task> planToday(Iterable<Task> tasks, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final endOfToday = DateTime(
      reference.year,
      reference.month,
      reference.day + 1,
    );
    final pending = tasks.where((task) => task.isPending).toList()
      ..sort((first, second) {
        final firstBucket = _planningBucket(first, reference, endOfToday);
        final secondBucket = _planningBucket(second, reference, endOfToday);
        final bucketOrder = firstBucket.compareTo(secondBucket);
        if (bucketOrder != 0) return bucketOrder;
        final priorityOrder = _priorityWeight(
          first.priority,
        ).compareTo(_priorityWeight(second.priority));
        if (priorityOrder != 0) return priorityOrder;
        return first.dateTime.compareTo(second.dateTime);
      });
    return List.unmodifiable(pending.take(3).toList());
  }

  int _planningBucket(Task task, DateTime now, DateTime endOfToday) {
    if (task.dateTime.isBefore(now)) return 0;
    if (task.dateTime.isBefore(endOfToday)) return 1;
    return 2;
  }

  int _priorityWeight(TaskPriority priority) => switch (priority) {
    TaskPriority.high => 0,
    TaskPriority.medium => 1,
    TaskPriority.low => 2,
  };
}
