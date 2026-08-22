import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/services/study_session_summary.dart';

void main() {
  final today = DateTime(2026, 8, 21);

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

  test('resume apenas sessões iniciadas hoje', () {
    final sessions = [
      session(
        id: 'today',
        startedAt: DateTime(2026, 8, 21, 10),
        duration: const Duration(minutes: 25),
      ),
      session(
        id: 'yesterday',
        startedAt: DateTime(2026, 8, 20, 10),
        duration: const Duration(minutes: 40),
      ),
    ];

    expect(
      StudySessionSummary.totalForDay(sessions, today),
      const Duration(minutes: 25),
    );
  });

  test('soma sessões e agrupa por matéria', () {
    final sessions = [
      session(
        id: 'math-1',
        subject: 'Matemática',
        startedAt: DateTime(2026, 8, 21, 10),
        duration: const Duration(minutes: 25),
      ),
      session(
        id: 'math-2',
        subject: 'Matemática',
        startedAt: DateTime(2026, 8, 21, 12),
        duration: const Duration(minutes: 15),
      ),
      session(
        id: 'physics',
        subject: 'Física',
        startedAt: DateTime(2026, 8, 21, 14),
        duration: const Duration(minutes: 20),
      ),
    ];

    expect(
      StudySessionSummary.totalForDay(sessions, today),
      const Duration(minutes: 60),
    );
    expect(StudySessionSummary.totalBySubjectForDay(sessions, today), {
      'Matemática': const Duration(minutes: 40),
      'Física': const Duration(minutes: 20),
    });
  });
}
