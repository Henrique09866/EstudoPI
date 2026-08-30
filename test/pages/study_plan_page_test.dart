import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/app/theme/app_theme.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/study_weekly_goal.dart';
import 'package:taskflow/pages/study_plan_page.dart';
import 'package:taskflow/services/study_session_storage.dart';

void main() {
  testWidgets('cria uma meta semanal e exibe o progresso da matéria', (
    tester,
  ) async {
    final now = DateTime.now();
    final storage = _GoalStorage();
    final session = StudySession(
      id: 'math-enem',
      subject: 'Matemática',
      studyPlan: 'ENEM',
      startedAt: now.subtract(const Duration(minutes: 60)),
      endedAt: now,
      duration: const Duration(minutes: 60),
      type: StudySessionType.pomodoro,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StudyPlanPage(
          storage: storage,
          sessions: [session],
          suggestedPlans: const ['ENEM'],
          suggestedSubjects: const ['Matemática'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('weekly-goal-plan-field')),
      'ENEM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weekly-goal-subject-field')),
      'Matemática',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weekly-goal-minutes-field')),
      '120',
    );
    final saveButton = find.byKey(const ValueKey('save-weekly-goal-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(storage.goals, hasLength(1));
    expect(storage.goals.single.targetMinutes, 120);
    expect(find.text('1h de 2h'), findsOneWidget);
  });
}

class _GoalStorage extends StudySessionStorage {
  final goals = <StudyWeeklyGoal>[];

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<int> getDailyGoalMinutes() async => 60;

  @override
  Future<List<StudySession>> getSessions() async => const [];

  @override
  Future<void> saveDailyGoalMinutes(int minutes) async {}

  @override
  Future<void> saveSession(StudySession session) async {}

  @override
  Future<void> saveWeeklyGoal(StudyWeeklyGoal goal) async {
    goals
      ..removeWhere((current) => current.id == goal.id)
      ..add(goal);
  }

  @override
  Future<void> deleteWeeklyGoal(String goalId) async {
    goals.removeWhere((goal) => goal.id == goalId);
  }

  @override
  Future<List<StudyWeeklyGoal>> getWeeklyGoals() async => List.of(goals);
}
