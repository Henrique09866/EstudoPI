import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/services/study_time_analytics.dart';

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

  test('soma horas por matéria e filtra pelo objetivo selecionado', () {
    final now = DateTime(2026, 8, 29, 20);
    final subjects = StudyTimeAnalytics.bySubject(
      sessions: [
        session(
          id: 'math-enem',
          subject: 'Matemática',
          studyPlan: 'ENEM',
          startedAt: now,
          duration: const Duration(minutes: 50),
        ),
        session(
          id: 'physics-enem',
          subject: 'Física',
          studyPlan: 'ENEM',
          startedAt: now,
          duration: const Duration(minutes: 20),
        ),
        session(
          id: 'math-efomm',
          subject: 'Matemática',
          studyPlan: 'EFOMM',
          startedAt: now,
          duration: const Duration(minutes: 30),
        ),
      ],
      period: StudyChartPeriod.today,
      studyPlan: 'ENEM',
      now: now,
    );

    expect(subjects.map((subject) => subject.subject), [
      'Matemática',
      'Física',
    ]);
    expect(subjects.first.duration, const Duration(minutes: 50));
    expect(StudyTimeAnalytics.total(subjects), const Duration(minutes: 70));
  });

  test('o período de sete dias não inclui uma sessão de oito dias', () {
    final now = DateTime(2026, 8, 29, 20);
    final subjects = StudyTimeAnalytics.bySubject(
      sessions: [
        session(
          id: 'recent',
          subject: 'Química',
          startedAt: now.subtract(const Duration(days: 6)),
          duration: const Duration(minutes: 25),
        ),
        session(
          id: 'old',
          subject: 'Biologia',
          startedAt: now.subtract(const Duration(days: 7)),
          duration: const Duration(minutes: 25),
        ),
      ],
      period: StudyChartPeriod.last7Days,
      now: now,
    );

    expect(subjects.map((subject) => subject.subject), ['Química']);
  });
}
