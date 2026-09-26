import '../models/mock_exam.dart';

class MockExamSubjectPerformance {
  const MockExamSubjectPerformance({
    required this.subject,
    required this.totalQuestions,
    required this.correctAnswers,
  });

  final String subject;
  final int totalQuestions;
  final int correctAnswers;

  double get accuracy =>
      totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;
}

class MockExamOverview {
  const MockExamOverview({
    required this.exams,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.subjects,
  });

  final List<MockExam> exams;
  final int totalQuestions;
  final int correctAnswers;
  final List<MockExamSubjectPerformance> subjects;

  double get accuracy =>
      totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;
  MockExam? get latest => exams.isEmpty ? null : exams.first;
}

class MockExamAnalytics {
  const MockExamAnalytics();

  MockExamOverview summarize(Iterable<MockExam> values) {
    final exams = values.toList()
      ..sort((first, second) => second.takenAt.compareTo(first.takenAt));
    final bySubject = <String, _SubjectTotals>{};
    var totalQuestions = 0;
    var correctAnswers = 0;
    for (final exam in exams) {
      totalQuestions += exam.totalQuestions;
      correctAnswers += exam.correctAnswers;
      for (final result in exam.subjectResults) {
        final key = result.subject.trim().toLowerCase();
        final totals = bySubject.putIfAbsent(
          key,
          () => _SubjectTotals(result.subject.trim()),
        );
        totals
          ..totalQuestions += result.totalQuestions
          ..correctAnswers += result.correctAnswers;
      }
    }
    final subjects =
        bySubject.values
            .map(
              (totals) => MockExamSubjectPerformance(
                subject: totals.subject,
                totalQuestions: totals.totalQuestions,
                correctAnswers: totals.correctAnswers,
              ),
            )
            .toList()
          ..sort((first, second) {
            final accuracyOrder = first.accuracy.compareTo(second.accuracy);
            return accuracyOrder != 0
                ? accuracyOrder
                : first.subject.compareTo(second.subject);
          });
    return MockExamOverview(
      exams: List.unmodifiable(exams),
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      subjects: List.unmodifiable(subjects),
    );
  }
}

class _SubjectTotals {
  _SubjectTotals(this.subject);

  final String subject;
  var totalQuestions = 0;
  var correctAnswers = 0;
}
