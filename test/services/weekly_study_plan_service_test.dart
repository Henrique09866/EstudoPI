import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/study_weekly_goal.dart';
import 'package:taskflow/services/weekly_study_plan_service.dart';

void main() {
  test('considera o tempo que já foi estudado hoje na distribuição', () {
    final now = DateTime(2026, 8, 24, 12); // segunda-feira
    final recommendations = const WeeklyStudyPlanService()
        .recommendationsForToday(
          now: now,
          goals: [
            StudyWeeklyGoal(
              studyPlan: 'ITA',
              subject: 'Matemática',
              targetMinutes: 420,
            ),
          ],
          sessions: [
            StudySession(
              id: 'math',
              subject: 'Matemática',
              studyPlan: 'ITA',
              startedAt: now.subtract(const Duration(minutes: 60)),
              endedAt: now,
              duration: const Duration(minutes: 60),
              type: StudySessionType.pomodoro,
            ),
          ],
        );

    expect(recommendations, isEmpty);
  });

  test('prioriza as matérias que pedem mais tempo hoje', () {
    final now = DateTime(2026, 8, 27, 12); // quinta-feira
    final recommendations = const WeeklyStudyPlanService()
        .recommendationsForToday(
          now: now,
          goals: [
            StudyWeeklyGoal(
              studyPlan: 'ITA',
              subject: 'Física',
              targetMinutes: 120,
            ),
            StudyWeeklyGoal(
              studyPlan: 'ITA',
              subject: 'Matemática',
              targetMinutes: 300,
            ),
          ],
          sessions: const [],
        );

    expect(recommendations.map((item) => item.subject), [
      'Matemática',
      'Física',
    ]);
    expect(recommendations.first.recommendedMinutes, 75);
  });
}
