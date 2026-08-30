import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_revision.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/services/study_revision_planner.dart';

void main() {
  const planner = StudyRevisionPlanner();
  final session = StudySession(
    id: 'physics-enem',
    subject: 'Física',
    studyPlan: 'ENEM',
    startedAt: DateTime(2026, 8, 10, 15),
    endedAt: DateTime(2026, 8, 10, 15, 25),
    duration: const Duration(minutes: 25),
    type: StudySessionType.pomodoro,
  );

  test('agenda revisões para 1, 7 e 30 dias após estudar uma matéria', () {
    final revisions = planner.revisionsFor(session);

    expect(revisions.map((revision) => revision.scheduledFor), [
      DateTime(2026, 8, 11),
      DateTime(2026, 8, 17),
      DateTime(2026, 9, 9),
    ]);
    expect(
      revisions.every((revision) => revision.suggestedMinutes == 15),
      isTrue,
    );
    expect(revisions.every((revision) => revision.studyPlan == 'ENEM'), isTrue);
  });

  test(
    'lista revisões vencidas e de hoje, sem trazer futuras ou concluídas',
    () {
      final revisions = [
        StudyRevision(
          id: 'overdue',
          subject: 'Matemática',
          scheduledFor: DateTime(2026, 8, 20),
        ),
        StudyRevision(
          id: 'today',
          subject: 'Física',
          scheduledFor: DateTime(2026, 8, 21),
        ),
        StudyRevision(
          id: 'future',
          subject: 'Química',
          scheduledFor: DateTime(2026, 8, 22),
        ),
        StudyRevision(
          id: 'done',
          subject: 'Biologia',
          scheduledFor: DateTime(2026, 8, 21),
          completedAt: DateTime(2026, 8, 21, 10),
        ),
      ];

      expect(
        planner
            .pendingForDay(revisions, DateTime(2026, 8, 21, 14))
            .map((revision) => revision.id),
        ['overdue', 'today'],
      );
    },
  );
}
