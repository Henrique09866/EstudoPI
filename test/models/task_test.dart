import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task.dart';

void main() {
  group('Task', () {
    final createdAt = DateTime(2026, 8, 21, 9);
    final futureDate = DateTime(2026, 8, 22, 10);

    Task createTask({
      String id = 'task-1',
      String title = 'Estudar Flutter',
      String? description = 'Revisar models em Dart',
      String? subject = 'Programação',
      DateTime? dateTime,
      TaskPriority priority = TaskPriority.medium,
      TaskCategory category = TaskCategory.study,
      ReminderOffset reminderOffset = ReminderOffset.atTime,
      TaskRecurrence recurrence = TaskRecurrence.none,
      List<int> recurrenceWeekdays = const [],
      bool isCompleted = false,
      DateTime? completedAt,
    }) {
      return Task(
        id: id,
        title: title,
        description: description,
        subject: subject,
        dateTime: dateTime ?? futureDate,
        priority: priority,
        category: category,
        reminderOffset: reminderOffset,
        recurrence: recurrence,
        recurrenceWeekdays: recurrenceWeekdays,
        isCompleted: isCompleted,
        completedAt: completedAt,
        createdAt: createdAt,
      );
    }

    test('creates a valid task', () {
      final task = createTask();

      expect(task.id, 'task-1');
      expect(task.title, 'Estudar Flutter');
      expect(task.description, 'Revisar models em Dart');
      expect(task.subject, 'Programação');
      expect(task.dateTime, futureDate);
      expect(task.priority, TaskPriority.medium);
      expect(task.category, TaskCategory.study);
      expect(task.reminderOffset, ReminderOffset.atTime);
      expect(task.recurrence, TaskRecurrence.none);
      expect(task.recurrenceWeekdays, isEmpty);
      expect(task.createdAt, createdAt);
    });

    test('uses false as the default isCompleted value', () {
      final task = Task(
        id: 'task-1',
        title: 'Estudar Flutter',
        dateTime: futureDate,
        priority: TaskPriority.medium,
        createdAt: createdAt,
      );

      expect(task.isCompleted, isFalse);
      expect(task.completedAt, isNull);
    });

    test('uses atTime as the default reminder offset', () {
      final task = createTask();

      expect(task.reminderOffset, ReminderOffset.atTime);
    });

    test('uses none as the default recurrence', () {
      final task = createTask();

      expect(task.recurrence, TaskRecurrence.none);
      expect(task.recurrenceWeekdays, isEmpty);
    });

    test('isPending is true when the task is not completed', () {
      final task = createTask();

      expect(task.isPending, isTrue);
    });

    test('isOverdue is true when pending and dateTime has passed', () {
      final task = createTask(dateTime: DateTime(2000));

      expect(task.isOverdue, isTrue);
    });

    test('completed task is not overdue', () {
      final task = createTask(dateTime: DateTime(2000), isCompleted: true);

      expect(task.isOverdue, isFalse);
    });

    test('copyWith returns a changed copy without mutating the original', () {
      final task = createTask();
      final completedTask = task.copyWith(isCompleted: true);

      expect(task.isCompleted, isFalse);
      expect(completedTask.isCompleted, isTrue);
      expect(completedTask.id, task.id);
      expect(completedTask.title, task.title);
      expect(completedTask.reminderOffset, task.reminderOffset);
      expect(completedTask.subject, task.subject);
      expect(completedTask.category, task.category);
      expect(completedTask.recurrence, task.recurrence);
    });

    test('copyWith define e limpa completedAt', () {
      final completedAt = DateTime(2026, 8, 21, 11);
      final completed = createTask(isCompleted: true, completedAt: completedAt);
      final pending = completed.copyWith(isCompleted: false, completedAt: null);

      expect(completed.completedAt, completedAt);
      expect(pending.isCompleted, isFalse);
      expect(pending.completedAt, isNull);
    });

    test('copyWith changes reminder offset', () {
      final task = createTask();
      final updatedTask = task.copyWith(
        reminderOffset: ReminderOffset.thirtyMinutes,
      );

      expect(task.reminderOffset, ReminderOffset.atTime);
      expect(updatedTask.reminderOffset, ReminderOffset.thirtyMinutes);
    });

    test('copyWith changes subject and category', () {
      final task = createTask();
      final updatedTask = task.copyWith(
        subject: 'Física',
        category: TaskCategory.exam,
      );

      expect(task.subject, 'Programação');
      expect(task.category, TaskCategory.study);
      expect(updatedTask.subject, 'Física');
      expect(updatedTask.category, TaskCategory.exam);
    });

    test('copyWith changes recurrence and weekdays', () {
      final task = createTask();
      final updatedTask = task.copyWith(
        recurrence: TaskRecurrence.customWeekdays,
        recurrenceWeekdays: [DateTime.friday, DateTime.monday, 9],
      );

      expect(updatedTask.recurrence, TaskRecurrence.customWeekdays);
      expect(updatedTask.recurrenceWeekdays, [
        DateTime.monday,
        DateTime.friday,
      ]);
    });

    test('compares tasks by value', () {
      final firstTask = createTask();
      final secondTask = createTask();

      expect(firstTask, secondTask);
      expect(firstTask.hashCode, secondTask.hashCode);
    });

    test('rejects empty titles', () {
      expect(() => createTask(title: '   '), throwsA(isA<ArgumentError>()));
    });

    test('serializes to map', () {
      final task = createTask();

      expect(task.toMap(), {
        'id': 'task-1',
        'title': 'Estudar Flutter',
        'description': 'Revisar models em Dart',
        'subject': 'Programação',
        'dateTime': futureDate.toIso8601String(),
        'priority': 'medium',
        'category': 'study',
        'reminderOffset': 'atTime',
        'recurrence': 'none',
        'recurrenceWeekdays': <int>[],
        'isCompleted': false,
        'completedAt': null,
        'createdAt': createdAt.toIso8601String(),
      });
    });

    test('deserializes from map preserving priority and dates', () {
      final task = Task.fromMap({
        'id': 'task-1',
        'title': 'Estudar Flutter',
        'description': 'Revisar models em Dart',
        'subject': 'Física',
        'dateTime': futureDate.toIso8601String(),
        'priority': 'high',
        'category': 'exam',
        'reminderOffset': 'oneHour',
        'recurrence': 'customWeekdays',
        'recurrenceWeekdays': [1, 3, 5],
        'isCompleted': true,
        'completedAt': DateTime(2026, 8, 21, 12).toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      });

      expect(task.priority, TaskPriority.high);
      expect(task.subject, 'Física');
      expect(task.category, TaskCategory.exam);
      expect(task.reminderOffset, ReminderOffset.oneHour);
      expect(task.recurrence, TaskRecurrence.customWeekdays);
      expect(task.recurrenceWeekdays, [1, 3, 5]);
      expect(task.dateTime, futureDate);
      expect(task.createdAt, createdAt);
      expect(task.isCompleted, isTrue);
      expect(task.completedAt, DateTime(2026, 8, 21, 12));
    });

    test('deserializes old maps without reminder offset', () {
      final task = Task.fromMap({
        'id': 'task-1',
        'title': 'Estudar Flutter',
        'description': 'Revisar models em Dart',
        'dateTime': futureDate.toIso8601String(),
        'priority': 'low',
        'isCompleted': false,
        'createdAt': createdAt.toIso8601String(),
      });

      expect(task.reminderOffset, ReminderOffset.atTime);
      expect(task.subject, isNull);
      expect(task.category, TaskCategory.other);
      expect(task.recurrence, TaskRecurrence.none);
      expect(task.recurrenceWeekdays, isEmpty);
      expect(task.completedAt, isNull);
    });

    test('uses safe defaults for unknown priority and reminder offset', () {
      final task = Task.fromMap({
        'id': 'task-1',
        'title': 'Estudar Flutter',
        'description': null,
        'dateTime': futureDate.toIso8601String(),
        'priority': 'unknown',
        'category': 'invalid',
        'reminderOffset': 'invalid',
        'recurrence': 'invalid',
        'recurrenceWeekdays': [0, 1, 8, 5],
        'isCompleted': false,
        'createdAt': createdAt.toIso8601String(),
      });

      expect(task.priority, TaskPriority.medium);
      expect(task.reminderOffset, ReminderOffset.atTime);
      expect(task.category, TaskCategory.other);
      expect(task.recurrence, TaskRecurrence.none);
      expect(task.recurrenceWeekdays, [1, 5]);
    });
  });
}
