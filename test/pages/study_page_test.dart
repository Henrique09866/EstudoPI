import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/app/theme/app_theme.dart';
import 'package:taskflow/models/study_cycle_subject.dart';
import 'package:taskflow/models/study_revision.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/pages/home_page.dart';
import 'package:taskflow/pages/study_page.dart';
import 'package:taskflow/services/study_session_storage.dart';
import 'package:taskflow/services/study_timer_alarm_scheduler.dart';
import 'package:taskflow/services/study_timer_controller.dart';
import 'package:taskflow/services/task_storage.dart';

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

void main() {
  late DateTime now;
  late FakeStudyStorage storage;
  late FakeTimerAlarms timerAlarms;
  late StudyTimerController controller;

  setUp(() {
    // Mantém as sessões do fixture no mesmo dia exibido pela tela.
    final current = DateTime.now();
    now = DateTime(current.year, current.month, current.day, 12);
    storage = FakeStudyStorage();
    timerAlarms = FakeTimerAlarms();
    controller = StudyTimerController(now: () => now);
  });

  Widget buildStudy() => MaterialApp(
    theme: AppTheme.light,
    home: StudyPage(
      storage: storage,
      timerController: controller,
      timerAlarms: timerAlarms,
      subjects: const ['Física', 'Matemática'],
    ),
  );

  testWidgets('organiza sessão, painel e revisões em abas', (tester) async {
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    expect(find.text('Área de estudos'), findsOneWidget);
    expect(find.text('Sessão'), findsOneWidget);
    expect(find.text('Painel'), findsOneWidget);
    expect(find.text('Revisões'), findsOneWidget);
    expect(find.text('Ciclo'), findsOneWidget);
    expect(find.text('Pomodoro'), findsOneWidget);
    expect(find.text('Cronômetro'), findsOneWidget);
    expect(find.byKey(const ValueKey('study-plan-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('study-subject-field')), findsOneWidget);
    expect(find.text('Meta de hoje'), findsOneWidget);

    await _tapVisible(tester, find.text('Painel'));
    await tester.pumpAndSettle();
    expect(find.text('Tempo por matéria'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Barras'), findsOneWidget);

    await _tapVisible(tester, find.text('Sessão'));
    await tester.pumpAndSettle();
    expect(find.text('Sessões de hoje'), findsOneWidget);
    expect(find.text('00:25:00'), findsNothing);
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('Home abre a Área de estudos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          initialTasks: const [],
          storage: _NoopTaskStorage(),
          studyStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('start-study-from-home-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Área de estudos'), findsOneWidget);
  });

  testWidgets('matérias do ciclo não aparecem como sugestões da sessão', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StudyPage(
          storage: storage,
          timerController: controller,
          timerAlarms: timerAlarms,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Ciclo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-cycle-subject-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cycle-subject-name-field')),
      'Física',
    );
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Sessão'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'Física'), findsNothing);
  });

  testWidgets('cronômetro livre salva sessão válida ao finalizar', (
    tester,
  ) async {
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cronômetro'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('study-subject-field')),
      'Física',
    );
    await tester.enterText(
      find.byKey(const ValueKey('study-notes-field')),
      'Resolver os exercícios 4 e 5.',
    );
    await _tapVisible(tester, find.byKey(const ValueKey('study-start-button')));
    await tester.pump();
    now = now.add(const Duration(minutes: 2));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('study-finish-button')),
    );
    await tester.pumpAndSettle();

    expect(storage.sessions, hasLength(1));
    expect(storage.sessions.single.duration, const Duration(minutes: 2));
    expect(storage.sessions.single.subject, 'Física');
    expect(storage.sessions.single.notes, 'Resolver os exercícios 4 e 5.');
    expect(find.text('Resolver os exercícios 4 e 5.'), findsOneWidget);
    expect(find.text('Sessões de hoje'), findsOneWidget);
  });

  testWidgets('salva o objetivo e alterna o gráfico entre pizza e barras', (
    tester,
  ) async {
    storage.sessions.addAll([
      StudySession(
        id: 'math-enem',
        subject: 'Matemática',
        studyPlan: 'ENEM',
        startedAt: DateTime.now().subtract(const Duration(minutes: 50)),
        endedAt: DateTime.now(),
        duration: const Duration(minutes: 50),
        type: StudySessionType.pomodoro,
      ),
      StudySession(
        id: 'physics-enem',
        subject: 'Física',
        studyPlan: 'ENEM',
        startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        endedAt: DateTime.now(),
        duration: const Duration(minutes: 25),
        type: StudySessionType.pomodoro,
      ),
    ]);
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Painel'));
    await tester.pumpAndSettle();
    expect(find.text('Matemática'), findsWidgets);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('study-chart-type-bars')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('study-chart-type-bars')), findsOneWidget);

    await _tapVisible(tester, find.text('Sessão'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const ValueKey('study-plan-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENEM').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('study-subject-field')),
      'Geografia',
    );
    await _tapVisible(tester, find.byKey(const ValueKey('study-start-button')));
    await tester.pump();
    now = now.add(const Duration(minutes: 2));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('study-finish-button')),
    );
    await tester.pumpAndSettle();

    expect(storage.sessions.last.studyPlan, 'ENEM');
  });

  testWidgets('Pomodoro mostra e cancela o alarme no horário previsto', (
    tester,
  ) async {
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey('study-start-button')));
    await tester.pump();

    expect(timerAlarms.scheduledAt, [now.add(const Duration(minutes: 25))]);
    expect(
      find.byKey(const ValueKey('study-timer-alarm-time')),
      findsOneWidget,
    );

    await _tapVisible(tester, find.byKey(const ValueKey('study-pause-button')));
    await tester.pump();
    expect(timerAlarms.cancelCount, 1);
  });

  testWidgets('mostra revisão pendente e permite marcá-la como revisada', (
    tester,
  ) async {
    final revision = StudyRevision(
      id: 'revision-physics',
      subject: 'Física',
      studyPlan: 'ENEM',
      scheduledFor: DateTime.now(),
    );
    storage.revisions.add(revision);
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Revisões'));
    await tester.pumpAndSettle();
    expect(find.text('Revisões de hoje'), findsOneWidget);
    expect(find.text('15 min · ENEM'), findsOneWidget);
    final completeButton = find.byKey(
      ValueKey('complete-revision-${revision.id}'),
    );
    await _tapVisible(tester, completeButton);
    await tester.pumpAndSettle();

    expect(storage.revisions.single.isCompleted, isTrue);
    expect(find.textContaining('Tudo em dia.'), findsOneWidget);
  });

  testWidgets('cria um ciclo, marca uma matéria e abre o histórico', (
    tester,
  ) async {
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Ciclo'));
    await tester.pumpAndSettle();
    expect(find.text('Seu ciclo da semana'), findsOneWidget);
    expect(find.text('Crie seu primeiro ciclo'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('add-cycle-subject-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cycle-subject-name-field')),
      'Matemática',
    );
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(storage.cycleSubjects.single.name, 'Matemática');
    final day = StudyCycleCalendar.weekDays(
      DateTime.now(),
    ).lastWhere((value) => !value.isAfter(DateTime.now()));
    final checkInButton = find.byKey(
      ValueKey(
        'cycle-check-in-${storage.cycleSubjects.single.id}-${StudyCycleCalendar.dayKey(day)}',
      ),
    );
    await _tapVisible(tester, checkInButton);
    await tester.pumpAndSettle();
    expect(storage.cycleCheckIns, hasLength(1));

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('open-cycle-history-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Histórico do ciclo'), findsOneWidget);
    expect(find.text('Presença no estudo'), findsOneWidget);
  });

  testWidgets('sessão curta não é persistida', (tester) async {
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey('study-start-button')));
    await tester.pump();
    now = now.add(const Duration(seconds: 30));
    final finishButton = find.byKey(const ValueKey('study-finish-button'));
    await tester.ensureVisible(finishButton);
    await tester.tap(finishButton);
    await tester.pumpAndSettle();

    expect(storage.sessions, isEmpty);
    expect(
      find.text('Sessões com menos de 1 minuto não são salvas.'),
      findsOneWidget,
    );
  });

  testWidgets('altera meta diária e exclui sessão registrada', (tester) async {
    storage.sessions.add(
      StudySession(
        id: 'study-existing',
        subject: 'Matemática',
        startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        endedAt: DateTime.now(),
        duration: const Duration(minutes: 25),
        type: StudySessionType.pomodoro,
      ),
    );
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    final goalButton = find.byKey(const ValueKey('edit-daily-goal-button'));
    await tester.ensureVisible(goalButton);
    await tester.tap(goalButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('90 min'));
    await tester.pumpAndSettle();
    expect(storage.dailyGoalMinutes, 90);
    expect(find.text('25 min / 90 min'), findsOneWidget);

    final deleteButton = find.byTooltip('Excluir sessão');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();
    expect(storage.sessions, isEmpty);
  });

  testWidgets('não gera overflow em viewport pequeno', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    expect(find.text('Área de estudos'), findsOneWidget);
    expect(find.byKey(const ValueKey('study-start-button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapVisible(tester, find.text('Painel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _tapVisible(tester, find.text('Revisões'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _tapVisible(tester, find.text('Ciclo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renderiza em viewport desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    expect(find.text('Área de estudos'), findsOneWidget);
    expect(find.text('Meta de hoje'), findsOneWidget);
    await _tapVisible(tester, find.text('Painel'));
    await tester.pumpAndSettle();
    expect(find.text('Tempo por matéria'), findsOneWidget);
  });
}

class FakeStudyStorage extends StudySessionStorage {
  final sessions = <StudySession>[];
  final revisions = <StudyRevision>[];
  final cycleSubjects = <StudyCycleSubject>[];
  final cycleCheckIns = <StudyCycleCheckIn>[];
  var dailyGoalMinutes = 60;

  @override
  Future<void> deleteSession(String id) async {
    sessions.removeWhere((session) => session.id == id);
  }

  @override
  Future<int> getDailyGoalMinutes() async => dailyGoalMinutes;

  @override
  Future<List<StudySession>> getSessions() async => List.of(sessions);

  @override
  Future<void> saveDailyGoalMinutes(int minutes) async {
    dailyGoalMinutes = minutes;
  }

  @override
  Future<void> saveSession(StudySession session) async {
    sessions.add(session);
  }

  @override
  Future<List<StudyRevision>> getRevisions() async => List.of(revisions);

  @override
  Future<void> saveRevision(StudyRevision revision) async {
    revisions
      ..removeWhere((current) => current.id == revision.id)
      ..add(revision);
  }

  @override
  Future<List<StudyCycleSubject>> getCycleSubjects() async =>
      List.of(cycleSubjects);

  @override
  Future<void> saveCycleSubject(StudyCycleSubject subject) async {
    cycleSubjects
      ..removeWhere((current) => current.id == subject.id)
      ..add(subject);
  }

  @override
  Future<void> deleteCycleSubject(String subjectId) async {
    cycleSubjects.removeWhere((subject) => subject.id == subjectId);
    cycleCheckIns.removeWhere((checkIn) => checkIn.subjectId == subjectId);
  }

  @override
  Future<List<StudyCycleCheckIn>> getCycleCheckIns() async =>
      List.of(cycleCheckIns);

  @override
  Future<void> saveCycleCheckIn(StudyCycleCheckIn checkIn) async {
    cycleCheckIns
      ..removeWhere((current) => current.id == checkIn.id)
      ..add(checkIn);
  }

  @override
  Future<void> deleteCycleCheckIn(String checkInId) async {
    cycleCheckIns.removeWhere((checkIn) => checkIn.id == checkInId);
  }
}

class FakeTimerAlarms implements StudyTimerAlarmScheduler {
  final scheduledAt = <DateTime>[];
  var cancelCount = 0;

  @override
  bool get canScheduleNotifications => true;

  @override
  Future<void> cancelStudyTimerAlarm() async {
    cancelCount++;
  }

  @override
  Future<void> scheduleStudyTimerAlarm({
    required DateTime scheduledAt,
    required StudyTimerAlarmKind kind,
    String? subject,
    bool sound = true,
    bool vibration = true,
  }) async {
    this.scheduledAt.add(scheduledAt);
  }
}

class _NoopTaskStorage implements TaskStorage {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<Task>> getTasks() async => const [];

  @override
  Future<void> saveTask(Task task) async {}

  @override
  Future<void> updateTask(Task task) async {}
}
