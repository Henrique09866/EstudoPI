import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taskflow/models/study_session.dart';
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
}
