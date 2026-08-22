import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/services/task_storage_service.dart';

void main() {
  late Directory tempDir;
  late TaskStorageService storage;

  final createdAt = DateTime(2026, 8, 21, 9);
  final dateTime = DateTime(2026, 8, 22, 10, 30);

  Task createTask({
    String id = 'task-1',
    String title = 'Estudar Flutter',
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      title: title,
      description: 'Persistir localmente',
      subject: 'Programação',
      dateTime: dateTime,
      priority: TaskPriority.medium,
      category: TaskCategory.study,
      recurrence: TaskRecurrence.customWeekdays,
      recurrenceWeekdays: [DateTime.monday, DateTime.wednesday],
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taskflow_hive_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<dynamic>(TaskStorageService.boxName);
    storage = TaskStorageService(box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('salvar tarefa', () async {
    final task = createTask();

    await storage.saveTask(task);

    final tasks = await storage.getTasks();
    expect(tasks, [task]);
  });

  test('carregar tarefas', () async {
    final firstTask = createTask();
    final secondTask = createTask(id: 'task-2', title: 'Comprar caderno');

    await storage.saveTask(firstTask);
    await storage.saveTask(secondTask);

    final tasks = await storage.getTasks();
    expect(tasks, containsAll([firstTask, secondTask]));
  });

  test('persiste matéria, categoria e recorrência', () async {
    final task = createTask();

    await storage.saveTask(task);

    final restoredTask = (await storage.getTasks()).single;
    expect(restoredTask.subject, 'Programação');
    expect(restoredTask.category, TaskCategory.study);
    expect(restoredTask.recurrence, TaskRecurrence.customWeekdays);
    expect(restoredTask.recurrenceWeekdays, [
      DateTime.monday,
      DateTime.wednesday,
    ]);
  });

  test('editar tarefa persistida', () async {
    final task = createTask();
    final editedTask = task.copyWith(title: 'Estudar Hive');

    await storage.saveTask(task);
    await storage.updateTask(editedTask);

    final tasks = await storage.getTasks();
    expect(tasks.single, editedTask);
  });

  test('concluir tarefa e manter status persistido', () async {
    final task = createTask();
    final completedAt = DateTime(2026, 8, 22, 11);
    final completedTask = task.copyWith(
      isCompleted: true,
      completedAt: completedAt,
    );

    await storage.saveTask(task);
    await storage.updateTask(completedTask);

    final tasks = await storage.getTasks();
    expect(tasks.single.isCompleted, isTrue);
    expect(tasks.single.completedAt, completedAt);
  });

  test('desconcluir tarefa', () async {
    final task = createTask(
      isCompleted: true,
    ).copyWith(completedAt: DateTime(2026, 8, 22, 11));
    final pendingTask = task.copyWith(isCompleted: false, completedAt: null);

    await storage.saveTask(task);
    await storage.updateTask(pendingTask);

    final tasks = await storage.getTasks();
    expect(tasks.single.isCompleted, isFalse);
    expect(tasks.single.completedAt, isNull);
  });

  test('excluir tarefa', () async {
    final task = createTask();

    await storage.saveTask(task);
    await storage.deleteTask(task.id);

    final tasks = await storage.getTasks();
    expect(tasks, isEmpty);
  });

  test('ignora registro inválido sem derrubar o carregamento', () async {
    final validTask = createTask();
    final box = Hive.box<dynamic>(TaskStorageService.boxName);

    await storage.saveTask(validTask);
    await box.put('invalid-task', {'id': 'invalid-task'});

    final tasks = await storage.getTasks();
    expect(tasks, [validTask]);
  });
}
