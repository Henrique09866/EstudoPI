import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taskflow/models/study_cycle_subject.dart';
import 'package:taskflow/models/study_revision.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/study_weekly_goal.dart';
import 'package:taskflow/services/study_session_storage_service.dart';

void main() {
  late Directory tempDir;
  late StudySessionStorageService storage;

  StudySession session(String id, {String? subject}) => StudySession(
    id: id,
    subject: subject,
    startedAt: DateTime(2026, 8, 21, 20),
    endedAt: DateTime(2026, 8, 21, 20, 25),
    duration: const Duration(minutes: 25),
    type: StudySessionType.pomodoro,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('estudo_pi_study_test_');
    Hive.init(tempDir.path);
    final sessionsBox = await Hive.openBox<dynamic>(
      StudySessionStorageService.sessionsBoxName,
    );
    final settingsBox = await Hive.openBox<dynamic>(
      StudySessionStorageService.settingsBoxName,
    );
    storage = StudySessionStorageService(sessionsBox, settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('salva, carrega e exclui sessão', () async {
    final item = session('study-1', subject: 'Física');
    await storage.saveSession(item);

    expect(await storage.getSessions(), [item]);

    await storage.deleteSession(item.id);
    expect(await storage.getSessions(), isEmpty);
  });

  test('mantém múltiplas sessões e ignora registro corrompido', () async {
    await storage.saveSession(session('study-1'));
    await storage.saveSession(session('study-2', subject: 'Matemática'));
    await Hive.box<dynamic>(
      StudySessionStorageService.sessionsBoxName,
    ).put('invalid', {'id': 'invalid'});

    final sessions = await storage.getSessions();
    expect(
      sessions,
      containsAll([
        session('study-1'),
        session('study-2', subject: 'Matemática'),
      ]),
    );
  });

  test('meta diária começa em 60 minutos e persiste alterações', () async {
    expect(
      await storage.getDailyGoalMinutes(),
      StudySessionStorageService.defaultDailyGoalMinutes,
    );

    await storage.saveDailyGoalMinutes(90);
    expect(await storage.getDailyGoalMinutes(), 90);
  });

  test(
    'persiste metas semanais e substitui a mesma matéria no objetivo',
    () async {
      final firstGoal = StudyWeeklyGoal(
        studyPlan: 'ENEM',
        subject: 'Matemática',
        targetMinutes: 180,
      );
      final updatedGoal = StudyWeeklyGoal(
        studyPlan: 'ENEM',
        subject: 'matemática',
        targetMinutes: 240,
      );

      await storage.saveWeeklyGoal(firstGoal);
      await storage.saveWeeklyGoal(updatedGoal);

      expect(await storage.getWeeklyGoals(), [updatedGoal]);

      await storage.deleteWeeklyGoal(updatedGoal.id);
      expect(await storage.getWeeklyGoals(), isEmpty);
    },
  );

  test('persiste revisões e permite concluir uma revisão', () async {
    final revision = StudyRevision(
      id: 'revision-physics',
      subject: 'Física',
      studyPlan: 'ENEM',
      scheduledFor: DateTime(2026, 8, 22),
    );
    await storage.saveRevision(revision);

    expect(await storage.getRevisions(), [revision]);

    final completed = revision.copyWith(completedAt: DateTime(2026, 8, 22, 12));
    await storage.saveRevision(completed);
    expect(await storage.getRevisions(), [completed]);
  });

  test('persiste o ciclo e apaga marcações ao remover uma matéria', () async {
    const subject = StudyCycleSubject(
      id: 'cycle-math',
      name: 'Matemática',
      colorIndex: 0,
    );
    final checkIn = StudyCycleCheckIn(
      subjectId: subject.id,
      day: DateTime(2026, 8, 24),
    );

    await storage.saveCycleSubject(subject);
    await storage.saveCycleCheckIn(checkIn);

    expect(await storage.getCycleSubjects(), [subject]);
    expect((await storage.getCycleCheckIns()).single.id, checkIn.id);

    await storage.deleteCycleSubject(subject.id);
    expect(await storage.getCycleSubjects(), isEmpty);
    expect(await storage.getCycleCheckIns(), isEmpty);
  });
}
