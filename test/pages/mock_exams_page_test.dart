import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/app/theme/app_theme.dart';
import 'package:taskflow/models/mock_exam.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/pages/mock_exams_page.dart';
import 'package:taskflow/services/study_session_storage.dart';

void main() {
  testWidgets('registra um simulado e exibe o aproveitamento', (tester) async {
    final storage = _MockExamStorage();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MockExamsPage(storage: storage),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Simulados'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-mock-exam-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mock-exam-title-field')),
      'AFA 2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mock-exam-questions-field')),
      '20',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mock-exam-correct-field')),
      '15',
    );
    final saveButton = find.byKey(const ValueKey('save-mock-exam-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(storage.exams, hasLength(1));
    expect(find.textContaining('75%'), findsWidgets);
    expect(find.text('AFA 2026'), findsOneWidget);
  });
}

class _MockExamStorage extends StudySessionStorage {
  final exams = <MockExam>[];

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
  Future<List<MockExam>> getMockExams() async => List.of(exams);

  @override
  Future<void> saveMockExam(MockExam exam) async => exams.add(exam);
}
