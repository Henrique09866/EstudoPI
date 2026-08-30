import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/app/theme/app_theme.dart';
import 'package:taskflow/models/study_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/pages/home_page.dart';
import 'package:taskflow/pages/progress_page.dart';
import 'package:taskflow/services/study_session_storage.dart';
import 'package:taskflow/services/task_storage.dart';

void main() {
  final now = DateTime.now();

  Task task({
    required String id,
    bool isCompleted = false,
    DateTime? completedAt,
  }) => Task(
    id: id,
    title: id,
    subject: 'Matemática',
    dateTime: now,
    priority: TaskPriority.medium,
    isCompleted: isCompleted,
    completedAt: completedAt,
    createdAt: now,
  );

  StudySession session() => StudySession(
    id: 'study-1',
    subject: 'Física',
    startedAt: now,
    endedAt: now.add(const Duration(minutes: 25)),
    duration: const Duration(minutes: 25),
    type: StudySessionType.pomodoro,
  );

  Widget buildProgress({
    List<Task> tasks = const [],
    List<StudySession> sessions = const [],
  }) => MaterialApp(
    theme: AppTheme.light,
    home: ProgressPage(tasks: tasks, initialSessions: sessions),
  );

  testWidgets('mostra períodos, métricas e ranking por matéria', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildProgress(
        tasks: [
          task(id: 'completed', isCompleted: true, completedAt: now),
          task(id: 'pending'),
        ],
        sessions: [session()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meu progresso'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('7 dias'), findsOneWidget);
    expect(find.text('30 dias'), findsOneWidget);
    expect(find.text('Tempo estudado'), findsOneWidget);
    expect(find.text('Atividades'), findsOneWidget);
    expect(find.text('Tarefas\nconcluídas'), findsOneWidget);
    expect(find.text('Tarefas\natrasadas'), findsOneWidget);
    expect(find.text('Concluídas\ncom atraso'), findsOneWidget);
    expect(find.text('Tempo por matéria'), findsOneWidget);
    expect(find.text('Física'), findsOneWidget);

    await tester.tap(find.text('7 dias'));
    await tester.pumpAndSettle();
    expect(find.text('Dias com estudo'), findsOneWidget);
  });

  testWidgets('exibe estado vazio sem dados', (tester) async {
    await tester.pumpWidget(buildProgress());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ainda não há dados suficientes. Conclua tarefas e registre sessões de estudo para acompanhar seu progresso.',
      ),
      findsOneWidget,
    );
    expect(find.text('0% das tarefas relevantes no período'), findsOneWidget);
  });

  testWidgets('Home abre Meu progresso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          initialTasks: const [],
          storage: _NoopTaskStorage(),
          studyStorage: _FakeStudyStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-progress-button')));
    await tester.pumpAndSettle();

    expect(find.text('Meu progresso'), findsOneWidget);
  });

  testWidgets('não gera overflow em viewport 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildProgress(sessions: [session()]));
    await tester.pumpAndSettle();

    expect(find.text('Meu progresso'), findsOneWidget);
    expect(find.text('Tempo por matéria'), findsOneWidget);
  });

  testWidgets('renderiza em viewport desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildProgress(sessions: [session()]));
    await tester.pumpAndSettle();

    expect(find.text('Meu progresso'), findsOneWidget);
    expect(find.text('Taxa de conclusão'), findsOneWidget);
  });
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

class _FakeStudyStorage extends StudySessionStorage {
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
}
