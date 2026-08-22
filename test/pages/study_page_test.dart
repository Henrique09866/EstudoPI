import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/app/theme/app_theme.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/pages/home_page.dart';
import 'package:taskflow/pages/study_page.dart';
import 'package:taskflow/services/study_session_storage.dart';
import 'package:taskflow/services/study_timer_controller.dart';
import 'package:taskflow/services/task_storage.dart';

void main() {
  late DateTime now;
  late FakeStudyStorage storage;
  late StudyTimerController controller;

  setUp(() {
    // Mantém as sessões do fixture no mesmo dia exibido pela tela.
    now = DateTime.now();
    storage = FakeStudyStorage();
    controller = StudyTimerController(now: () => now);
  });

  Widget buildStudy() => MaterialApp(
    theme: AppTheme.light,
    home: StudyPage(
      storage: storage,
      timerController: controller,
      subjects: const ['Física', 'Matemática'],
    ),
  );

  testWidgets('renderiza modos, matéria, meta e histórico', (tester) async {
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    expect(find.text('Modo Estudo'), findsOneWidget);
    expect(find.text('Pomodoro'), findsOneWidget);
    expect(find.text('Cronômetro'), findsOneWidget);
    expect(find.byKey(const ValueKey('study-subject-field')), findsOneWidget);
    expect(find.text('Meta de hoje'), findsOneWidget);
    expect(find.text('Sessões de hoje'), findsOneWidget);
    expect(find.text('00:25:00'), findsNothing);
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('Home abre o Modo Estudo', (tester) async {
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

    expect(find.text('Modo Estudo'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('study-start-button')));
    await tester.pump();
    now = now.add(const Duration(minutes: 2));
    await tester.tap(find.byKey(const ValueKey('study-finish-button')));
    await tester.pumpAndSettle();

    expect(storage.sessions, hasLength(1));
    expect(storage.sessions.single.duration, const Duration(minutes: 2));
    expect(storage.sessions.single.subject, 'Física');
    expect(find.text('Física'), findsWidgets);
    expect(find.text('2 min'), findsOneWidget);
  });

  testWidgets('sessão curta não é persistida', (tester) async {
    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('study-start-button')));
    await tester.pump();
    now = now.add(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('study-finish-button')));
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

    expect(find.text('Modo Estudo'), findsOneWidget);
    expect(find.byKey(const ValueKey('study-start-button')), findsOneWidget);
  });

  testWidgets('renderiza em viewport desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildStudy());
    await tester.pumpAndSettle();

    expect(find.text('Modo Estudo'), findsOneWidget);
    expect(find.text('Meta de hoje'), findsOneWidget);
  });
}

class FakeStudyStorage implements StudySessionStorage {
  final sessions = <StudySession>[];
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
