import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/mock_exam.dart';

void main() {
  test('preserva os dados do simulado e dos resultados por matéria', () {
    final exam = MockExam(
      id: 'mock-1',
      title: 'ITA 2025',
      studyPlan: 'ITA',
      takenAt: DateTime(2026, 8, 30),
      totalQuestions: 20,
      correctAnswers: 14,
      duration: const Duration(minutes: 90),
      subjectResults: const [
        MockExamSubjectResult(
          subject: 'Matemática',
          totalQuestions: 10,
          correctAnswers: 8,
        ),
      ],
      notes: 'Revisar geometria.',
    );

    final restored = MockExam.fromMap(exam.toMap());

    expect(restored, exam);
    expect(restored.accuracy, .7);
    expect(restored.subjectResults.single.accuracy, .8);
  });

  test('rejeita acertos maiores que o total', () {
    expect(
      () => MockExam.fromMap({
        'id': 'mock-1',
        'title': 'ENEM',
        'takenAt': DateTime(2026, 8, 30).toIso8601String(),
        'totalQuestions': 10,
        'correctAnswers': 11,
        'durationSeconds': 0,
      }),
      throwsFormatException,
    );
  });
}
