import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/services/study_timer_controller.dart';

void main() {
  late DateTime now;
  late StudyTimerController controller;

  setUp(() {
    now = DateTime(2026, 8, 21, 20);
    controller = StudyTimerController(
      now: () => now,
      pomodoroDuration: const Duration(minutes: 25),
      breakDuration: const Duration(minutes: 5),
    );
  });

  test('Pomodoro inicia em 25 minutos e alterna para pausa ao concluir', () {
    expect(controller.displayedDuration, const Duration(minutes: 25));
    expect(controller.alarmAt, isNull);

    controller.startOrResume();
    expect(controller.alarmAt, DateTime(2026, 8, 21, 20, 25));
    now = now.add(const Duration(minutes: 25));

    expect(controller.tick(), StudyTimerEvent.focusCompleted);
    final result = controller.completeFocus();
    expect(result.duration, const Duration(minutes: 25));
    expect(controller.phase, StudyTimerPhase.breakTime);
    expect(controller.displayedDuration, const Duration(minutes: 5));

    controller.startOrResume();
    now = now.add(const Duration(minutes: 5));
    expect(controller.tick(), StudyTimerEvent.breakCompleted);
    expect(controller.phase, StudyTimerPhase.focus);
  });

  test('pausa e continuação não contam tempo parado no cronômetro livre', () {
    controller.selectType(StudySessionType.freeTimer);
    controller.startOrResume();
    expect(controller.alarmAt, isNull);
    now = now.add(const Duration(minutes: 10));
    controller.pause();
    now = now.add(const Duration(minutes: 5));
    controller.startOrResume();
    now = now.add(const Duration(minutes: 20));

    final result = controller.finishStudy();

    expect(result.duration, const Duration(minutes: 30));
    expect(result.type, StudySessionType.freeTimer);
    expect(controller.hasActiveStudySession, isFalse);
  });

  test('pular pausa restaura novo foco sem contar pausa como estudo', () {
    controller.startOrResume();
    now = now.add(const Duration(minutes: 25));
    controller.tick();
    controller.completeFocus();
    controller.startOrResume();
    now = now.add(const Duration(minutes: 2));
    controller.skipBreak();

    expect(controller.phase, StudyTimerPhase.focus);
    expect(controller.elapsed, Duration.zero);
    expect(controller.hasActiveStudySession, isFalse);
  });

  test(
    'usa pausa longa e inicia a pausa automaticamente quando configurado',
    () {
      final longBreakController = StudyTimerController(
        now: () => now,
        pomodoroDuration: const Duration(minutes: 25),
        breakDuration: const Duration(minutes: 5),
        longBreakDuration: const Duration(minutes: 20),
        focusSessionsBeforeLongBreak: 1,
        autoStartBreak: true,
      );

      longBreakController.startOrResume();
      now = now.add(const Duration(minutes: 25));
      expect(longBreakController.tick(), StudyTimerEvent.focusCompleted);
      longBreakController.completeFocus();

      expect(longBreakController.isLongBreak, isTrue);
      expect(
        longBreakController.displayedDuration,
        const Duration(minutes: 20),
      );
      expect(longBreakController.isRunning, isTrue);
    },
  );
}
