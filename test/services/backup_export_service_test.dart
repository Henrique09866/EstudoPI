import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/app_settings.dart';
import 'package:taskflow/models/mock_exam.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/study_weekly_goal.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/services/backup_export_service.dart';

void main() {
  test('cria backup JSON, planilha CSV e relatório PDF localmente', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'curujao_export_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final now = DateTime(2026, 8, 30, 18, 30);
    final result =
        await BackupExportService(
          documentsDirectory: () async => temporaryDirectory,
          now: () => now,
        ).exportAll(
          BackupExportData(
            settings: const AppSettings(),
            tasks: [
              Task(
                id: 'task-1',
                title: 'Resolver lista',
                dateTime: now,
                priority: TaskPriority.medium,
                createdAt: now,
              ),
            ],
            sessions: [
              StudySession(
                id: 'session-1',
                subject: 'Física',
                startedAt: now.subtract(const Duration(minutes: 30)),
                endedAt: now,
                duration: const Duration(minutes: 30),
                type: StudySessionType.pomodoro,
              ),
            ],
            weeklyGoals: [
              StudyWeeklyGoal(
                studyPlan: 'ITA',
                subject: 'Física',
                targetMinutes: 180,
              ),
            ],
            revisions: const [],
            mockExams: [
              MockExam(
                id: 'mock-1',
                title: 'ITA',
                takenAt: now,
                totalQuestions: 10,
                correctAnswers: 8,
              ),
            ],
          ),
        );

    expect(await result.backupFile.exists(), isTrue);
    expect(await result.csvFile.exists(), isTrue);
    expect(await result.pdfFile.exists(), isTrue);
    final backup = jsonDecode(await result.backupFile.readAsString()) as Map;
    expect(backup['formatVersion'], 1);
    expect(backup['mockExams'], hasLength(1));
    expect(await result.csvFile.readAsString(), contains('meta semanal'));
    expect(await result.pdfFile.readAsString(), startsWith('%PDF-1.4'));
  });
}
