import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/mock_exam.dart';
import 'package:taskflow/services/mock_exam_analytics.dart';

void main() {
  test('soma acertos e ordena as matérias com menor desempenho primeiro', () {
    final overview = const MockExamAnalytics().summarize([
      MockExam(
        id: 'first',
        title: 'AFA',
        takenAt: DateTime(2026, 8, 1),
        totalQuestions: 20,
        correctAnswers: 14,
        subjectResults: const [
          MockExamSubjectResult(
            subject: 'Matemática',
            totalQuestions: 10,
            correctAnswers: 8,
          ),
          MockExamSubjectResult(
            subject: 'Física',
            totalQuestions: 10,
            correctAnswers: 6,
          ),
        ],
      ),
      MockExam(
        id: 'latest',
        title: 'AFA',
        takenAt: DateTime(2026, 8, 8),
        totalQuestions: 10,
        correctAnswers: 8,
        subjectResults: const [
          MockExamSubjectResult(
            subject: 'Física',
            totalQuestions: 10,
            correctAnswers: 8,
          ),
        ],
      ),
    ]);

    expect(overview.totalQuestions, 30);
    expect(overview.correctAnswers, 22);
    expect(overview.latest?.id, 'latest');
    expect(overview.subjects.map((subject) => subject.subject), [
      'Física',
      'Matemática',
    ]);
    expect(overview.subjects.first.accuracy, .7);
  });
}
