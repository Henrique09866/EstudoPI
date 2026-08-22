import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/services/task_recurrence_service.dart';

void main() {
  final service = TaskRecurrenceService();
  final createdAt = DateTime(2026, 8, 21, 9);

  Task taskFixture({
    TaskRecurrence recurrence = TaskRecurrence.none,
    List<int> recurrenceWeekdays = const [],
    DateTime? dateTime,
    DateTime? completedAt,
  }) {
    return Task(
      id: 'task-original',
      title: 'Revisar cinemática',
      description: 'Capítulo 3',
      subject: 'Física',
      dateTime: dateTime ?? DateTime(2026, 8, 21, 18, 30),
      priority: TaskPriority.high,
      category: TaskCategory.study,
      reminderOffset: ReminderOffset.thirtyMinutes,
      recurrence: recurrence,
      recurrenceWeekdays: recurrenceWeekdays,
      completedAt: completedAt,
      createdAt: createdAt,
    );
  }

  test(
    'recorrência diária cria tarefa no dia seguinte preservando horário',
    () {
      final task = taskFixture(recurrence: TaskRecurrence.daily);

      final nextTask = service.createNextOccurrence(
        task,
        createdAt: DateTime(2026, 8, 21, 10),
        now: DateTime(2026, 8, 21, 19),
      );

      expect(nextTask?.dateTime, DateTime(2026, 8, 22, 18, 30));
      expect(nextTask?.id, isNot(task.id));
      expect(nextTask?.isCompleted, isFalse);
      expect(nextTask?.completedAt, isNull);
    },
  );

  test('recorrência semanal cria tarefa na semana seguinte', () {
    final task = taskFixture(recurrence: TaskRecurrence.weekly);

    final nextTask = service.createNextOccurrence(
      task,
      now: DateTime(2026, 8, 21, 19),
    );

    expect(nextTask?.dateTime, DateTime(2026, 8, 28, 18, 30));
  });

  test('dias específicos encontra o próximo dia selecionado', () {
    final task = taskFixture(
      recurrence: TaskRecurrence.customWeekdays,
      recurrenceWeekdays: [
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      ],
      dateTime: DateTime(2026, 8, 19, 18, 30),
    );

    final nextTask = service.createNextOccurrence(
      task,
      now: DateTime(2026, 8, 19, 19),
    );

    expect(nextTask?.dateTime, DateTime(2026, 8, 21, 18, 30));
  });

  test('dias específicos avança de sexta para segunda', () {
    final task = taskFixture(
      recurrence: TaskRecurrence.customWeekdays,
      recurrenceWeekdays: [
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      ],
    );

    final nextTask = service.createNextOccurrence(
      task,
      now: DateTime(2026, 8, 21, 19),
    );

    expect(nextTask?.dateTime, DateTime(2026, 8, 24, 18, 30));
  });

  test('tarefa sem recorrência não cria próxima ocorrência', () {
    expect(service.createNextOccurrence(taskFixture()), isNull);
  });

  test('tarefa atrasada avança até uma próxima ocorrência futura', () {
    final task = taskFixture(
      recurrence: TaskRecurrence.daily,
      dateTime: DateTime(2026, 8, 18, 18, 30),
    );

    final nextTask = service.createNextOccurrence(
      task,
      now: DateTime(2026, 8, 21, 19),
    );

    expect(nextTask?.dateTime, DateTime(2026, 8, 22, 18, 30));
  });

  test('próxima ocorrência preserva os dados de estudo e lembrete', () {
    final task = taskFixture(recurrence: TaskRecurrence.daily);

    final nextTask = service.createNextOccurrence(
      task,
      now: DateTime(2026, 8, 21, 19),
    );

    expect(nextTask?.title, task.title);
    expect(nextTask?.description, task.description);
    expect(nextTask?.subject, task.subject);
    expect(nextTask?.priority, task.priority);
    expect(nextTask?.category, task.category);
    expect(nextTask?.reminderOffset, task.reminderOffset);
    expect(nextTask?.recurrence, task.recurrence);
  });

  test('próxima ocorrência não copia a data de conclusão', () {
    final completedTask = taskFixture(
      recurrence: TaskRecurrence.daily,
      completedAt: DateTime(2026, 8, 21, 19),
    );

    final nextTask = service.createNextOccurrence(
      completedTask,
      now: DateTime(2026, 8, 21, 19),
    );

    expect(nextTask?.isCompleted, isFalse);
    expect(nextTask?.completedAt, isNull);
  });
}
