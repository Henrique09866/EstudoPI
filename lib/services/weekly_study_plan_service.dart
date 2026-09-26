import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import 'study_plan_progress.dart';

class DailyStudyRecommendation {
  const DailyStudyRecommendation({
    required this.progress,
    required this.recommendedMinutes,
    required this.todayStudied,
  });

  final WeeklyGoalProgress progress;
  final int recommendedMinutes;
  final Duration todayStudied;

  String get subject => progress.goal.subject;
  String? get studyPlan => progress.goal.studyPlan;
  Duration get remaining => progress.remaining;
}

/// Distribui o tempo restante das metas entre os dias que faltam na semana.
class WeeklyStudyPlanService {
  const WeeklyStudyPlanService({
    this.progressService = const StudyPlanProgressService(),
  });

  final StudyPlanProgressService progressService;

  List<DailyStudyRecommendation> recommendationsForToday({
    required Iterable<StudySession> sessions,
    required Iterable<StudyWeeklyGoal> goals,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final daysRemaining = DateTime.sunday - current.weekday + 1;
    final sessionList = sessions.toList(growable: false);
    final progress = progressService.calculate(
      sessions: sessionList,
      goals: goals,
      now: current,
    );
    final result =
        progress
            .where((item) => item.remaining > Duration.zero)
            .map((item) {
              final todayStudied = _studiedToday(
                sessionList,
                subject: item.goal.subject,
                studyPlan: item.goal.studyPlan,
                now: current,
              );
              final evenlyDistributed =
                  (item.remaining.inMinutes / daysRemaining).ceil();
              return DailyStudyRecommendation(
                progress: item,
                recommendedMinutes: (evenlyDistributed - todayStudied.inMinutes)
                    .clamp(0, item.remaining.inMinutes),
                todayStudied: todayStudied,
              );
            })
            .where((item) => item.recommendedMinutes > 0)
            .toList()
          ..sort((first, second) {
            final recommendationOrder = second.recommendedMinutes.compareTo(
              first.recommendedMinutes,
            );
            return recommendationOrder != 0
                ? recommendationOrder
                : first.subject.compareTo(second.subject);
          });
    return List.unmodifiable(result);
  }

  static Duration _studiedToday(
    Iterable<StudySession> sessions, {
    required String subject,
    required String? studyPlan,
    required DateTime now,
  }) {
    return sessions
        .where(
          (session) =>
              _isSameDay(session.startedAt, now) &&
              _normalize(session.subject) == _normalize(subject) &&
              _normalize(session.studyPlan) == _normalize(studyPlan),
        )
        .fold(Duration.zero, (total, session) => total + session.duration);
  }

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
}
