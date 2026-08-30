import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/services/home_insights_service.dart';

void main() {
  const service = HomeInsightsService();
  final now = DateTime(2026, 8, 21, 20);

  StudySession session(String id, DateTime startedAt, {String? subject}) =>
      StudySession(
        id: id,
        subject: subject,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 30)),
        duration: const Duration(minutes: 30),
        type: StudySessionType.pomodoro,
      );

  Task task({
    required String id,
    required DateTime dateTime,
    TaskPriority priority = TaskPriority.medium,
  }) => Task(
    id: id,
    title: id,
    dateTime: dateTime,
    priority: priority,
    createdAt: now,
  );

  test('calcula a sequência de dias estudados até hoje', () {
    expect(
      service.studyStreak([
        session('today', now),
        session('yesterday', now.subtract(const Duration(days: 1))),
        session('two-days', now.subtract(const Duration(days: 2))),
        session('old', now.subtract(const Duration(days: 4))),
      ], now: now),
      3,
    );
  });

  test('resume a semana e prioriza atrasadas antes de tarefas futuras', () {
    final sessions = [
      session('physics', now, subject: 'Física'),
      session(
        'math',
        now.subtract(const Duration(days: 1)),
        subject: 'Matemática',
      ),
    ];
    final tasks = [
      task(
        id: 'future-high',
        dateTime: now.add(const Duration(days: 1)),
        priority: TaskPriority.high,
      ),
      task(
        id: 'overdue-medium',
        dateTime: now.subtract(const Duration(hours: 2)),
      ),
      task(id: 'today-low', dateTime: now.add(const Duration(hours: 1))),
    ];

    final summary = service.weeklySummary(
      sessions: sessions,
      tasks: tasks,
      now: now,
    );

    expect(summary.duration, const Duration(hours: 1));
    expect(summary.subjects.first.subject, 'Física');
    expect(summary.overdueTasks, 1);
    expect(service.planToday(tasks, now: now).map((item) => item.id), [
      'overdue-medium',
      'today-low',
      'future-high',
    ]);
  });
}
