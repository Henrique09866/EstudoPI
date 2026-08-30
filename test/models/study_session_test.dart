import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';

void main() {
  final startedAt = DateTime(2026, 8, 21, 20);
  final endedAt = DateTime(2026, 8, 21, 20, 25);

  StudySession createSession({
    String? subject,
    String? studyPlan,
    String? notes,
  }) => StudySession(
    id: 'study-1',
    subject: subject,
    studyPlan: studyPlan,
    notes: notes,
    startedAt: startedAt,
    endedAt: endedAt,
    duration: const Duration(minutes: 25),
    type: StudySessionType.pomodoro,
  );

  test('cria sessão imutável com matéria opcional', () {
    final session = createSession();

    expect(session.subject, isNull);
    expect(session.duration, const Duration(minutes: 25));
    expect(session.type, StudySessionType.pomodoro);
  });

  test('serializa e desserializa sessão', () {
    final session = createSession(
      subject: 'Física',
      studyPlan: 'ENEM',
      notes: 'Resolver exercícios.',
    );

    expect(StudySession.fromMap(session.toMap()), session);
  });

  test('igualdade considera todos os campos', () {
    expect(
      createSession(subject: 'Matemática'),
      createSession(subject: 'Matemática'),
    );
    expect(
      createSession(subject: 'Física'),
      isNot(createSession(subject: 'Química')),
    );
  });

  test('sessões antigas sem objetivo continuam válidas', () {
    final map = createSession(subject: 'Física').toMap()..remove('studyPlan');

    expect(StudySession.fromMap(map).studyPlan, isNull);
  });

  test('sessões antigas sem nota continuam válidas', () {
    final map = createSession(subject: 'Física').toMap()..remove('notes');

    expect(StudySession.fromMap(map).notes, isNull);
  });

  test('dados inválidos são rejeitados com segurança', () {
    expect(() => StudySession.fromMap({'id': 'broken'}), throwsFormatException);
    expect(
      () => StudySession.fromMap({
        'id': 'broken',
        'startedAt': endedAt.toIso8601String(),
        'endedAt': startedAt.toIso8601String(),
        'durationSeconds': 10,
      }),
      throwsFormatException,
    );
  });
}
