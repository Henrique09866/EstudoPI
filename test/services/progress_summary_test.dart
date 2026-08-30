import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/pages/progress_page.dart';
import 'package:taskflow/services/progress_summary.dart';

void main() {
  const service = ProgressSummaryService();
  final now = DateTime(2026, 8, 21, 15);

  Task task({
    required String id,
    required DateTime dateTime,
    bool isCompleted = false,
    DateTime? completedAt,
  }) => Task(
    id: id,
    title: id,
    dateTime: dateTime,
    priority: TaskPriority.medium,
    isCompleted: isCompleted,
    completedAt: completedAt,
    createdAt: now.subtract(const Duration(days: 10)),
  );

  StudySession session({
    required String id,
    required DateTime startedAt,
    required Duration duration,
    String? subject,
  }) => StudySession(
    id: id,
    subject: subject,
    startedAt: startedAt,
    endedAt: startedAt.add(duration),
    duration: duration,
    type: StudySessionType.freeTimer,
  );

  test('calcula métricas corretas para hoje', () {
    final summary = service.calculate(
      now: now,
      period: ProgressPeriod.today,
      tasks: [
        task(id: 'done', dateTime: now, isCompleted: true, completedAt: now),
        task(id: 'pending', dateTime: now.add(const Duration(hours: 2))),
        task(id: 'overdue', dateTime: now.subtract(const Duration(days: 1))),
      ],
      sessions: [
        session(
          id: 'math',
          subject: 'Matemática',
          startedAt: now,
          duration: const Duration(minutes: 40),
        ),
      ],
    );

    expect(summary.studyDuration, const Duration(minutes: 40));
    expect(summary.completedTasks, 1);
    expect(summary.pendingTasks, 1);
    expect(summary.overdueTasks, 0);
    expect(summary.completionRate, 0.5);
  });

  test('respeita os limites de 7 e 30 dias', () {
    final sessions = [
      session(
        id: 'six-days',
        startedAt: now.subtract(const Duration(days: 6)),
        duration: const Duration(minutes: 20),
      ),
      session(
        id: 'seven-days',
        startedAt: now.subtract(const Duration(days: 7)),
        duration: const Duration(minutes: 30),
      ),
      session(
        id: 'thirty-days',
        startedAt: now.subtract(const Duration(days: 30)),
        duration: const Duration(minutes: 40),
      ),
    ];

    expect(
      service
          .calculate(
            tasks: const [],
            sessions: sessions,
            period: ProgressPeriod.last7Days,
            now: now,
          )
          .studyDuration,
      const Duration(minutes: 20),
    );
    expect(
      service
          .calculate(
            tasks: const [],
            sessions: sessions,
            period: ProgressPeriod.last30Days,
            now: now,
          )
          .studyDuration,
      const Duration(minutes: 50),
    );
  });

  test('agrupa e ordena matéria, incluindo Sem matéria', () {
    final summary = service.calculate(
      tasks: const [],
      period: ProgressPeriod.today,
      now: now,
      sessions: [
        session(
          id: 'physics',
          subject: 'Física',
          startedAt: now,
          duration: const Duration(minutes: 20),
        ),
        session(
          id: 'none',
          startedAt: now,
          duration: const Duration(minutes: 30),
        ),
        session(
          id: 'math',
          subject: 'Matemática',
          startedAt: now,
          duration: const Duration(minutes: 40),
        ),
      ],
    );

    expect(summary.subjects.map((entry) => entry.subject), [
      'Matemática',
      'Sem matéria',
      'Física',
    ]);
  });

  test('separa tarefas concluídas no prazo das concluídas com atraso', () {
    final summary = service.calculate(
      now: now,
      period: ProgressPeriod.today,
      tasks: [
        task(
          id: 'on-time',
          dateTime: now.add(const Duration(hours: 1)),
          isCompleted: true,
          completedAt: now,
        ),
        task(
          id: 'late-completion',
          dateTime: now.subtract(const Duration(hours: 1)),
          isCompleted: true,
          completedAt: now,
        ),
        task(id: 'overdue', dateTime: now.subtract(const Duration(hours: 2))),
      ],
      sessions: const [],
    );

    expect(summary.completedTasks, 2);
    expect(summary.completedOnTimeTasks, 1);
    expect(summary.completedLateTasks, 1);
    expect(summary.overdueTasks, 1);
  });

  test(
    'lista vazia tem métricas seguras e duração acima de 24h é formatada',
    () {
      final summary = service.calculate(
        tasks: const [],
        sessions: const [],
        period: ProgressPeriod.today,
        now: now,
      );

      expect(summary.hasData, isFalse);
      expect(summary.completionRate, 0);
      expect(
        formatProgressDuration(const Duration(hours: 26, minutes: 5)),
        '26h 5min',
      );
    },
  );
}
