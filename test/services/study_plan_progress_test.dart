import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/study_weekly_goal.dart';
import 'package:taskflow/services/study_plan_progress.dart';

void main() {
  StudySession session({
    required String id,
    required String subject,
    String? studyPlan,
    required DateTime startedAt,
    required Duration duration,
  }) => StudySession(
    id: id,
    subject: subject,
    studyPlan: studyPlan,
    startedAt: startedAt,
    endedAt: startedAt.add(duration),
    duration: duration,
    type: StudySessionType.pomodoro,
  );

  test('compara o estudo da semana com a meta da mesma matéria e objetivo', () {
    const service = StudyPlanProgressService();
    final now = DateTime(2026, 8, 27, 20); // quinta-feira
    final progress = service.calculate(
      now: now,
      goals: [
        StudyWeeklyGoal(
          studyPlan: 'ENEM',
          subject: 'Matemática',
          targetMinutes: 180,
        ),
      ],
      sessions: [
        session(
          id: 'math-one',
          subject: 'matemática',
          studyPlan: 'ENEM',
          startedAt: DateTime(2026, 8, 25, 10),
          duration: const Duration(minutes: 90),
        ),
        session(
          id: 'math-other-plan',
          subject: 'Matemática',
          studyPlan: 'EFOMM',
          startedAt: DateTime(2026, 8, 25, 14),
          duration: const Duration(minutes: 90),
        ),
        session(
          id: 'math-old-week',
          subject: 'Matemática',
          studyPlan: 'ENEM',
          startedAt: DateTime(2026, 8, 17, 10),
          duration: const Duration(minutes: 90),
        ),
      ],
    );

    expect(progress.single.studied, const Duration(minutes: 90));
    expect(progress.single.remaining, const Duration(minutes: 90));
    expect(progress.single.completion, .5);
  });
}
