import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';

class WeeklyGoalProgress {
  const WeeklyGoalProgress({required this.goal, required this.studied});

  final StudyWeeklyGoal goal;
  final Duration studied;

  Duration get target => Duration(minutes: goal.targetMinutes);

  double get completion => target == Duration.zero
      ? 0
      : (studied.inSeconds / target.inSeconds).clamp(0.0, 1.0);

  Duration get remaining {
    final value = target - studied;
    return value.isNegative ? Duration.zero : value;
  }
}

class StudyPlanProgressService {
  const StudyPlanProgressService();

  List<WeeklyGoalProgress> calculate({
    required Iterable<StudySession> sessions,
    required Iterable<StudyWeeklyGoal> goals,
    DateTime? now,
  }) {
    final range = _weekFor(now ?? DateTime.now());
    final sessionList = sessions.toList();
    final progress =
        goals.map((goal) {
          final studied = sessionList
              .where(
                (session) =>
                    range.contains(session.startedAt) &&
                    _samePlan(session.studyPlan, goal.studyPlan) &&
                    _normalize(session.subject) == _normalize(goal.subject),
              )
              .fold(
                Duration.zero,
                (total, session) => total + session.duration,
              );
          return WeeklyGoalProgress(goal: goal, studied: studied);
        }).toList()..sort((first, second) {
          final planOrder = (first.goal.studyPlan ?? '').compareTo(
            second.goal.studyPlan ?? '',
          );
          return planOrder != 0
              ? planOrder
              : first.goal.subject.compareTo(second.goal.subject);
        });
    return List.unmodifiable(progress);
  }

  _StudyWeekRange _weekFor(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    return _StudyWeekRange(
      start: start,
      endExclusive: start.add(const Duration(days: 7)),
    );
  }

  static bool _samePlan(String? first, String? second) =>
      _normalize(first) == _normalize(second);

  static String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
}

class _StudyWeekRange {
  const _StudyWeekRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);
}
