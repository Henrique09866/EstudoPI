import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow/models/task.dart';
import 'package:taskflow/pages/calendar_page.dart';
import 'package:taskflow/pages/home_page.dart';
import 'package:taskflow/pages/task_form_page.dart';
import 'package:taskflow/services/notification_service.dart';
import 'package:taskflow/services/task_notification_scheduler.dart';
import 'package:taskflow/services/task_storage.dart';

void main() {
  final createdAt = DateTime(2026, 8, 21, 9);

  DateTime todayAt(int hour, [int minute = 0]) {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  Task taskFixture({
    String id = 'today-1',
    String title = 'Tarefa de hoje',
    String description = 'Descrição da tarefa',
    String? subject = 'Física',
    DateTime? dateTime,
    TaskPriority priority = TaskPriority.high,
    TaskCategory category = TaskCategory.study,
    ReminderOffset reminderOffset = ReminderOffset.atTime,
    TaskRecurrence recurrence = TaskRecurrence.none,
    List<int> recurrenceWeekdays = const [],
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      title: title,
      description: description,
      subject: subject,
      dateTime: dateTime ?? todayAt(9),
      priority: priority,
      category: category,
      reminderOffset: reminderOffset,
      recurrence: recurrence,
      recurrenceWeekdays: recurrenceWeekdays,
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }

  List<Task> tasksFixture() {
    return [
      taskFixture(),
      Task(
        id: 'future-1',
        title: 'Tarefa futura',
        dateTime: todayAt(10).add(const Duration(days: 1)),
        priority: TaskPriority.medium,
        createdAt: createdAt,
      ),
      taskFixture(id: 'done-1', title: 'Tarefa concluída', isCompleted: true),
    ];
  }

  Widget buildHome({
    FakeTaskStorage? storage,
    FakeNotificationScheduler? notifications,
  }) {
    return MaterialApp(
      home: HomePage(
        storage: storage ?? FakeTaskStorage(),
        notifications: notifications ?? FakeNotificationScheduler(),
      ),
    );
  }

  Widget buildForm({Task? task}) {
    return MaterialApp(home: TaskFormPage(task: task));
  }

  Future<void> pumpLoadedHome(
    WidgetTester tester, {
    FakeTaskStorage? storage,
    FakeNotificationScheduler? notifications,
  }) async {
    await tester.pumpWidget(
      buildHome(storage: storage, notifications: notifications),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openNewTaskForm(WidgetTester tester) async {
    final newTaskButton = find.byKey(const ValueKey('new-task-button'));
    await tester.ensureVisible(newTaskButton);
    await tester.tap(newTaskButton);
    await tester.pumpAndSettle();
  }

  Future<void> openTaskActions(WidgetTester tester, String taskId) async {
    final actionsButton = find.byKey(ValueKey('task-actions-$taskId'));

    await tester.ensureVisible(actionsButton);
    await tester.tap(actionsButton);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Home carrega tarefas do serviço', (tester) async {
    await pumpLoadedHome(tester, storage: FakeTaskStorage(tasksFixture()));

    expect(find.text('Estudo Pi'), findsOneWidget);
    expect(find.text('TaskFlow'), findsNothing);
    expect(find.text('Resumo de hoje'), findsOneWidget);
    expect(find.text('1 de 2 concluídas'), findsOneWidget);
    expect(find.text('Tarefa de hoje'), findsOneWidget);
    expect(find.text('Tarefa futura'), findsOneWidget);
    expect(find.text('Tarefa concluída'), findsOneWidget);
  });

  testWidgets('primeira execução sem tarefas funciona', (tester) async {
    await pumpLoadedHome(tester);

    expect(find.text('0 de 0 concluídas'), findsOneWidget);
    expect(find.text('Nenhuma tarefa cadastrada.'), findsOneWidget);
  });

  testWidgets('botão Nova tarefa abre o formulário', (tester) async {
    await pumpLoadedHome(tester);

    await openNewTaskForm(tester);

    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-title-field')), findsOneWidget);
  });

  testWidgets('Home abre o calendário', (tester) async {
    await pumpLoadedHome(tester);

    await tester.tap(find.byKey(const ValueKey('open-calendar-button')));
    await tester.pumpAndSettle();

    expect(find.text('Calendário'), findsOneWidget);
  });

  testWidgets('formulário renderiza corretamente', (tester) async {
    await tester.pumpWidget(buildForm());

    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Descrição'), findsOneWidget);
    expect(find.text('Matéria'), findsOneWidget);
    expect(find.text('Categoria'), findsOneWidget);
    expect(find.text('Prioridade'), findsOneWidget);
    expect(find.text('Lembrete'), findsOneWidget);
    expect(find.text('No horário'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-date-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-time-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-task-button')), findsOneWidget);
  });

  testWidgets('opções de lembrete aparecem corretamente', (tester) async {
    await tester.pumpWidget(buildForm());

    await tapVisible(tester, find.byKey(const ValueKey('task-reminder-field')));

    expect(find.text('No horário'), findsWidgets);
    expect(find.text('10 minutos antes'), findsOneWidget);
    expect(find.text('30 minutos antes'), findsOneWidget);
    expect(find.text('1 hora antes'), findsOneWidget);
  });

  testWidgets('formulário aceita matéria personalizada e categoria', (
    tester,
  ) async {
    final storage = FakeTaskStorage();
    await pumpLoadedHome(tester, storage: storage);
    await openNewTaskForm(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Preparar apresentação',
    );
    await tester.enterText(
      find.byKey(const ValueKey('task-subject-field')),
      'Projeto Integrador',
    );
    await tapVisible(tester, find.byKey(const ValueKey('task-category-field')));
    await tester.tap(find.text('Trabalho').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(storage.tasks.single.subject, 'Projeto Integrador');
    expect(storage.tasks.single.category, TaskCategory.assignment);
  });

  testWidgets('título obrigatório rejeita valor vazio', (tester) async {
    await tester.pumpWidget(buildForm());

    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));
    await tester.pump();

    expect(find.text('Informe um título para a tarefa.'), findsOneWidget);
  });

  testWidgets('criação válida salva e adiciona uma tarefa', (tester) async {
    final storage = FakeTaskStorage();
    await pumpLoadedHome(tester, storage: storage);

    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Estudar matemática',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(find.text('Estudar matemática'), findsOneWidget);
    expect(storage.tasks.single.title, 'Estudar matemática');
  });

  testWidgets('criar tarefa agenda notificação', (tester) async {
    final storage = FakeTaskStorage();
    final notifications = FakeNotificationScheduler();
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );

    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Estudar matemática',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(storage.tasks.single.title, 'Estudar matemática');
    expect(notifications.scheduledTasks.single.title, 'Estudar matemática');
  });

  testWidgets('alteração do lembrete é salva na Task', (tester) async {
    final storage = FakeTaskStorage();
    await pumpLoadedHome(tester, storage: storage);

    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Tarefa com lembrete',
    );
    await tapVisible(tester, find.byKey(const ValueKey('task-reminder-field')));
    await tester.tap(find.text('30 minutos antes').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(storage.tasks.single.reminderOffset, ReminderOffset.thirtyMinutes);
  });

  testWidgets('tarefa criada aparece na seção correta', (tester) async {
    await pumpLoadedHome(tester);

    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Tarefa criada hoje',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(find.text('Hoje'), findsAtLeastNWidgets(1));
    expect(find.text('Tarefa criada hoje'), findsOneWidget);
  });

  testWidgets('edição abre com dados existentes', (tester) async {
    await pumpLoadedHome(tester, storage: FakeTaskStorage([taskFixture()]));

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('task-title-field')),
    );
    final subjectField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('task-subject-field')),
    );

    expect(find.text('Editar tarefa'), findsOneWidget);
    expect(titleField.controller?.text, 'Tarefa de hoje');
    expect(subjectField.controller?.text, 'Física');
  });

  testWidgets('edição carrega lembrete anteriormente selecionado', (
    tester,
  ) async {
    await pumpLoadedHome(
      tester,
      storage: FakeTaskStorage([
        taskFixture(reminderOffset: ReminderOffset.oneHour),
      ]),
    );

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('1 hora antes'), findsOneWidget);
  });

  testWidgets('editar altera e persiste a tarefa', (tester) async {
    final storage = FakeTaskStorage([taskFixture()]);
    await pumpLoadedHome(tester, storage: storage);

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Tarefa editada',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(find.text('Tarefa editada'), findsOneWidget);
    expect(storage.tasks.single.title, 'Tarefa editada');
  });

  testWidgets('editar tarefa reageenda notificação', (tester) async {
    final storage = FakeTaskStorage([
      taskFixture(dateTime: DateTime.now().add(const Duration(days: 1))),
    ]);
    final notifications = FakeNotificationScheduler();
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );
    notifications.clear();

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Tarefa reagendada',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(notifications.cancelledTaskIds, contains('today-1'));
    expect(notifications.scheduledTasks.single.title, 'Tarefa reagendada');
  });

  testWidgets('edição mantém o mesmo id', (tester) async {
    final storage = FakeTaskStorage([taskFixture()]);
    await pumpLoadedHome(tester, storage: storage);

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Mesmo id',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(find.byKey(const ValueKey('task-card-today-1')), findsOneWidget);
    expect(storage.tasks.single.id, 'today-1');
  });

  testWidgets('exclusão abre confirmação', (tester) async {
    await pumpLoadedHome(tester, storage: FakeTaskStorage([taskFixture()]));

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir tarefa?'), findsOneWidget);
    expect(
      find.text('Tem certeza de que deseja excluir "Tarefa de hoje"?'),
      findsOneWidget,
    );
  });

  testWidgets('cancelar exclusão mantém a tarefa', (tester) async {
    final storage = FakeTaskStorage([taskFixture()]);
    await pumpLoadedHome(tester, storage: storage);

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Tarefa de hoje'), findsOneWidget);
    expect(storage.tasks.single.id, 'today-1');
  });

  testWidgets('confirmar exclusão remove a tarefa persistida', (tester) async {
    final storage = FakeTaskStorage([taskFixture()]);
    final notifications = FakeNotificationScheduler();
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );
    notifications.clear();

    await openTaskActions(tester, 'today-1');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();

    expect(find.text('Tarefa de hoje'), findsNothing);
    expect(storage.tasks, isEmpty);
    expect(notifications.cancelledTaskIds, ['today-1']);
  });

  testWidgets('marcar como concluída persiste status', (tester) async {
    final storage = FakeTaskStorage([taskFixture()]);
    final notifications = FakeNotificationScheduler();
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );
    notifications.clear();

    await tapVisible(tester, find.byType(Checkbox).first);
    await tester.pump();

    expect(storage.tasks.single.isCompleted, isTrue);
    expect(storage.tasks.single.completedAt, isNotNull);
    expect(notifications.cancelledTaskIds, ['today-1']);
  });

  testWidgets('desmarcar uma tarefa concluída persiste status', (tester) async {
    final storage = FakeTaskStorage([
      taskFixture(
        id: 'done-1',
        title: 'Tarefa concluída',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        isCompleted: true,
      ),
    ]);
    final notifications = FakeNotificationScheduler();
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );
    notifications.clear();

    final completedTaskCheckbox = find.byType(Checkbox).last;

    await tester.ensureVisible(completedTaskCheckbox);
    await tapVisible(tester, completedTaskCheckbox);
    await tester.pump();

    expect(
      storage.tasks.singleWhere((task) => task.id == 'done-1').isCompleted,
      isFalse,
    );
    expect(
      storage.tasks.singleWhere((task) => task.id == 'done-1').completedAt,
      isNull,
    );
    expect(notifications.scheduledTasks.single.id, 'done-1');
  });

  testWidgets('desconcluir atrasada não agenda', (tester) async {
    final storage = FakeTaskStorage([
      taskFixture(
        id: 'done-1',
        title: 'Tarefa concluída',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        isCompleted: true,
      ),
    ]);
    final notifications = FakeNotificationScheduler();
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );
    notifications.clear();

    await tapVisible(tester, find.byType(Checkbox).first);
    await tester.pump();

    expect(storage.tasks.single.isCompleted, isFalse);
    expect(notifications.scheduledTasks, isEmpty);
  });

  testWidgets('tarefa atrasada fica visível com indicação acessível', (
    tester,
  ) async {
    final overdueTask = taskFixture(
      id: 'overdue-1',
      title: 'Revisão pendente',
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
    );

    await pumpLoadedHome(tester, storage: FakeTaskStorage([overdueTask]));

    expect(find.text('Revisão pendente'), findsOneWidget);
    expect(find.text('Atrasada'), findsOneWidget);
  });

  testWidgets('erro de armazenamento não derruba o app', (tester) async {
    final storage = FakeTaskStorage()..throwOnSave = true;
    await pumpLoadedHome(tester, storage: storage);

    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Falha esperada',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(find.text('Não foi possível salvar a tarefa.'), findsOneWidget);
    expect(find.text('Falha esperada'), findsNothing);
    expect(storage.tasks, isEmpty);
  });

  testWidgets('falha no agendamento não remove a tarefa', (tester) async {
    final storage = FakeTaskStorage();
    final notifications = FakeNotificationScheduler()..throwOnSchedule = true;
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );

    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Lembrete com falha',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(storage.tasks.single.title, 'Lembrete com falha');
    expect(
      find.text('Tarefa salva, mas não foi possível agendar o lembrete.'),
      findsOneWidget,
    );
  });

  testWidgets('Home continua funcionando quando notificações não disponíveis', (
    tester,
  ) async {
    final storage = FakeTaskStorage();
    final notifications = FakeNotificationScheduler()
      ..canScheduleNotificationsValue = false;
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );

    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Sem suporte a lembrete',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(storage.tasks.single.title, 'Sem suporte a lembrete');
    expect(
      find.text('Lembretes agendados não estão disponíveis nesta plataforma.'),
      findsOneWidget,
    );
  });

  testWidgets('formulário não gera overflow em viewport pequena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildForm());

    expect(find.byKey(const ValueKey('task-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-date-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-time-button')), findsOneWidget);
  });

  testWidgets('Home não gera overflow em viewport pequena', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLoadedHome(tester, storage: FakeTaskStorage(tasksFixture()));

    expect(find.text('Estudo Pi'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-task-button')), findsOneWidget);
  });

  testWidgets('Home renderiza em viewport desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLoadedHome(tester, storage: FakeTaskStorage(tasksFixture()));

    expect(find.text('Estudo Pi'), findsOneWidget);
    expect(find.text('Resumo de hoje'), findsOneWidget);
  });

  testWidgets('pesquisa por título ignora maiúsculas e espaços', (
    tester,
  ) async {
    await pumpLoadedHome(
      tester,
      storage: FakeTaskStorage([
        taskFixture(title: 'Revisar cinemática'),
        taskFixture(id: 'other', title: 'Ler capítulo'),
      ]),
    );

    await tester.enterText(
      find.byKey(const ValueKey('task-search-field')),
      '  CINEMÁTICA ',
    );
    await tester.pumpAndSettle();

    expect(find.text('Revisar cinemática'), findsOneWidget);
    expect(find.text('Ler capítulo'), findsNothing);
  });

  testWidgets('pesquisa por descrição e matéria', (tester) async {
    await pumpLoadedHome(
      tester,
      storage: FakeTaskStorage([
        taskFixture(
          title: 'Sem título relacionado',
          description: 'Resolver questões de vetores',
          subject: 'Física',
        ),
        taskFixture(
          id: 'history',
          title: 'Outra tarefa',
          description: 'Ler resumo',
          subject: 'História',
        ),
      ]),
    );

    await tester.enterText(
      find.byKey(const ValueKey('task-search-field')),
      'vetores',
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem título relacionado'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task-search-field')),
      'história',
    );
    await tester.pumpAndSettle();
    expect(find.text('Outra tarefa'), findsOneWidget);
    expect(find.text('Sem título relacionado'), findsNothing);
  });

  testWidgets('pesquisa sem resultado e limpar busca restaura lista', (
    tester,
  ) async {
    await pumpLoadedHome(tester, storage: FakeTaskStorage([taskFixture()]));

    await tester.enterText(
      find.byKey(const ValueKey('task-search-field')),
      'inexistente',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma tarefa encontrada.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-clear-filters-button')));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa de hoje'), findsOneWidget);
  });

  testWidgets('filtros por status, prioridade, categoria e matéria', (
    tester,
  ) async {
    final now = DateTime.now();
    await pumpLoadedHome(
      tester,
      storage: FakeTaskStorage([
        taskFixture(
          id: 'exam',
          title: 'Prova de física',
          subject: 'Física',
          priority: TaskPriority.high,
          category: TaskCategory.exam,
          dateTime: now.add(const Duration(days: 1)),
        ),
        taskFixture(
          id: 'done',
          title: 'Trabalho concluído',
          subject: 'Matemática',
          category: TaskCategory.assignment,
          isCompleted: true,
        ),
      ]),
    );

    await tapVisible(tester, find.byKey(const ValueKey('filter-button')));
    await tapVisible(tester, find.byKey(const ValueKey('filter-status-field')));
    await tester.tap(find.text('Pendentes').last);
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('filter-priority-field')),
    );
    await tester.tap(find.text('Alta').last);
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('filter-category-field')),
    );
    await tester.tap(find.text('Prova').last);
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('filter-subject-field')),
    );
    await tester.tap(find.text('Física').last);
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('apply-filters-button')),
    );

    expect(find.text('Filtros (4)'), findsOneWidget);
    expect(find.text('Prova de física'), findsOneWidget);
    expect(find.text('Trabalho concluído'), findsNothing);
  });

  testWidgets('filtro de atrasadas mostra tarefa sem duplicar em hoje', (
    tester,
  ) async {
    final overdueTask = taskFixture(
      id: 'overdue-section',
      title: 'Lista atrasada',
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
    );
    await pumpLoadedHome(tester, storage: FakeTaskStorage([overdueTask]));

    expect(find.text('Atrasadas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-card-overdue-section')),
      findsOneWidget,
    );
    expect(find.text('Hoje'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('filter-button')));
    await tapVisible(tester, find.byKey(const ValueKey('filter-status-field')));
    await tester.tap(find.text('Atrasadas').last);
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('apply-filters-button')),
    );

    expect(find.text('Lista atrasada'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
  });

  testWidgets('limpar filtros restaura tarefas filtradas', (tester) async {
    await pumpLoadedHome(
      tester,
      storage: FakeTaskStorage([
        taskFixture(id: 'exam', title: 'Prova', category: TaskCategory.exam),
        taskFixture(id: 'study', title: 'Estudo'),
      ]),
    );

    await tapVisible(tester, find.byKey(const ValueKey('filter-button')));
    await tapVisible(
      tester,
      find.byKey(const ValueKey('filter-category-field')),
    );
    await tester.tap(find.text('Prova').last);
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('apply-filters-button')),
    );
    expect(find.text('Estudo'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-clear-filters-button')));
    await tester.pumpAndSettle();
    expect(find.text('Estudo'), findsAtLeastNWidgets(1));
  });

  testWidgets('formulário mostra opções de recorrência e salva dias', (
    tester,
  ) async {
    final storage = FakeTaskStorage();
    await pumpLoadedHome(tester, storage: storage);
    await openNewTaskForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Revisar inglês',
    );

    await tapVisible(
      tester,
      find.byKey(const ValueKey('task-recurrence-field')),
    );
    expect(find.text('Todos os dias'), findsOneWidget);
    expect(find.text('Toda semana'), findsOneWidget);
    expect(find.text('Dias específicos'), findsOneWidget);
    await tester.tap(find.text('Dias específicos').last);
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('recurrence-weekday-1')),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('recurrence-weekday-3')),
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-task-button')));

    expect(storage.tasks.single.recurrence, TaskRecurrence.customWeekdays);
    expect(storage.tasks.single.recurrenceWeekdays, [1, 3]);
  });

  testWidgets('concluir recorrente cria uma única próxima ocorrência', (
    tester,
  ) async {
    final recurringTask = taskFixture(
      id: 'daily-task',
      title: 'Ler em inglês',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      recurrence: TaskRecurrence.daily,
    );
    final storage = FakeTaskStorage([recurringTask]);
    final notifications = FakeNotificationScheduler();
    await pumpLoadedHome(
      tester,
      storage: storage,
      notifications: notifications,
    );
    notifications.clear();

    await tapVisible(tester, find.byType(Checkbox).first);

    expect(storage.tasks, hasLength(2));
    expect(
      storage.tasks.singleWhere((task) => task.id == 'daily-task').isCompleted,
      isTrue,
    );
    expect(
      storage.tasks.singleWhere((task) => task.id == 'daily-task').completedAt,
      isNotNull,
    );
    final nextTask = storage.tasks.singleWhere(
      (task) => task.id != 'daily-task',
    );
    expect(nextTask.isCompleted, isFalse);
    expect(nextTask.completedAt, isNull);
    expect(
      nextTask.dateTime,
      recurringTask.dateTime.add(const Duration(days: 1)),
    );
    expect(notifications.cancelledTaskIds, contains('daily-task'));
    expect(
      notifications.scheduledTasks.map((task) => task.id),
      contains(nextTask.id),
    );
  });

  testWidgets('concluir tarefa normal não cria ocorrência adicional', (
    tester,
  ) async {
    final storage = FakeTaskStorage([
      taskFixture(dateTime: DateTime.now().add(const Duration(days: 1))),
    ]);
    await pumpLoadedHome(tester, storage: storage);

    await tapVisible(tester, find.byType(Checkbox).first);

    expect(storage.tasks, hasLength(1));
    expect(storage.tasks.single.isCompleted, isTrue);
  });

  testWidgets('calendário abre, seleciona dia e lista tarefas concluídas', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 8, 21);
    final dayTask = taskFixture(
      id: 'calendar-day',
      title: 'Tarefa do dia',
      dateTime: DateTime(2026, 8, 21, 10),
    );
    final completedTask = taskFixture(
      id: 'calendar-done',
      title: 'Tarefa concluída do dia',
      dateTime: DateTime(2026, 8, 21, 12),
      isCompleted: true,
    );
    final otherTask = taskFixture(
      id: 'calendar-other',
      title: 'Tarefa de outro dia',
      dateTime: DateTime(2026, 8, 22, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage(
          initialTasks: [dayTask, completedTask, otherTask],
          initialSelectedDate: selectedDate,
          storage: FakeTaskStorage([dayTask, completedTask, otherTask]),
          notifications: FakeNotificationScheduler(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendário'), findsOneWidget);
    expect(find.text('Agosto 2026'), findsOneWidget);
    expect(find.text('Tarefa do dia'), findsOneWidget);
    expect(find.text('Tarefa concluída do dia'), findsOneWidget);
    expect(find.text('Tarefa de outro dia'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-8-22')));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa de outro dia'), findsOneWidget);
    expect(find.text('Tarefa do dia'), findsNothing);
  });

  testWidgets(
    'calendário abre formulário com a data selecionada e navega mês',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarPage(
            initialTasks: const [],
            initialSelectedDate: DateTime(2026, 8, 21),
            storage: FakeTaskStorage(),
            notifications: FakeNotificationScheduler(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('calendar-next-month-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Setembro 2026'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('calendar-previous-month-button')),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.byKey(const ValueKey('calendar-new-task-button')),
      );
      expect(find.text('Nova tarefa'), findsOneWidget);
      expect(find.text('21/08/2026'), findsOneWidget);
    },
  );

  testWidgets('calendário não gera overflow em viewport pequena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage(
          initialTasks: const [],
          initialSelectedDate: DateTime(2026, 8, 21),
          storage: FakeTaskStorage(),
          notifications: FakeNotificationScheduler(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendário'), findsOneWidget);
    expect(find.text('Agosto 2026'), findsOneWidget);
  });
}

class FakeTaskStorage implements TaskStorage {
  FakeTaskStorage([List<Task>? initialTasks])
    : tasks = List.of(initialTasks ?? []);

  final List<Task> tasks;
  bool throwOnSave = false;

  @override
  Future<List<Task>> getTasks() async {
    return List.of(tasks);
  }

  @override
  Future<void> saveTask(Task task) async {
    if (throwOnSave) {
      throw Exception('save failed');
    }

    tasks.add(task);
  }

  @override
  Future<void> updateTask(Task task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);

    if (index == -1) {
      tasks.add(task);
      return;
    }

    tasks[index] = task;
  }

  @override
  Future<void> deleteTask(String id) async {
    tasks.removeWhere((task) => task.id == id);
  }
}

class FakeNotificationScheduler implements TaskNotificationScheduler {
  final scheduledTasks = <Task>[];
  final cancelledTaskIds = <String>[];
  var canScheduleNotificationsValue = true;
  var throwOnSchedule = false;

  void clear() {
    scheduledTasks.clear();
    cancelledTaskIds.clear();
  }

  @override
  bool get canScheduleNotifications => canScheduleNotificationsValue;

  @override
  Future<bool> requestPermission() async => canScheduleNotificationsValue;

  @override
  Future<void> scheduleTaskNotification(Task task) async {
    if (!canScheduleNotificationsValue) {
      throw const NotificationUnavailableException(
        'Lembretes agendados não estão disponíveis nesta plataforma.',
      );
    }

    if (throwOnSchedule) {
      throw Exception('schedule failed');
    }

    if (NotificationService.shouldScheduleTaskNotification(task)) {
      scheduledTasks.add(task);
    }
  }

  @override
  Future<void> cancelTaskNotification(String taskId) async {
    cancelledTaskIds.add(taskId);
  }

  @override
  Future<void> rescheduleTaskNotification(Task task) async {
    await cancelTaskNotification(task.id);
    await scheduleTaskNotification(task);
  }

  @override
  Future<void> reconcileTaskNotifications(List<Task> tasks) async {
    for (final task in tasks) {
      if (NotificationService.shouldScheduleTaskNotification(task)) {
        await rescheduleTaskNotification(task);
      } else {
        await cancelTaskNotification(task.id);
      }
    }
  }
}
