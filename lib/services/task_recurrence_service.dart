import '../models/task.dart';

/// Creates one future task only when a recurring occurrence is completed.
///
/// No calendar horizon is pre-generated. Weekday values use [DateTime.monday]
/// (1) through [DateTime.sunday] (7).
class TaskRecurrenceService {
  Task? createNextOccurrence(Task task, {DateTime? createdAt, DateTime? now}) {
    final nextDateTime = _nextDateTimeFor(task, now ?? DateTime.now());
    if (nextDateTime == null) return null;

    final occurrenceCreatedAt = createdAt ?? DateTime.now();
    return Task(
      id: _newTaskId(occurrenceCreatedAt),
      title: task.title,
      description: task.description,
      subject: task.subject,
      dateTime: nextDateTime,
      priority: task.priority,
      category: task.category,
      reminderOffset: task.reminderOffset,
      recurrence: task.recurrence,
      recurrenceWeekdays: task.recurrenceWeekdays,
      createdAt: occurrenceCreatedAt,
    );
  }

  DateTime? _nextDateTimeFor(Task task, DateTime now) {
    final initialDateTime = switch (task.recurrence) {
      TaskRecurrence.none => null,
      TaskRecurrence.daily => _withSameTime(task.dateTime, daysToAdd: 1),
      TaskRecurrence.weekly => _withSameTime(task.dateTime, daysToAdd: 7),
      TaskRecurrence.customWeekdays => _nextCustomWeekday(task),
    };
    if (initialDateTime == null) return null;
    var nextDateTime = initialDateTime;

    while (!nextDateTime.isAfter(now)) {
      nextDateTime = _advanceOccurrence(task, nextDateTime);
    }
    return nextDateTime;
  }

  DateTime _advanceOccurrence(Task task, DateTime dateTime) {
    return switch (task.recurrence) {
      TaskRecurrence.daily => _withSameTime(dateTime, daysToAdd: 1),
      TaskRecurrence.weekly => _withSameTime(dateTime, daysToAdd: 7),
      TaskRecurrence.customWeekdays => _nextCustomWeekdayFrom(
        dateTime,
        task.recurrenceWeekdays,
      )!,
      TaskRecurrence.none => dateTime,
    };
  }

  DateTime? _nextCustomWeekday(Task task) {
    return _nextCustomWeekdayFrom(task.dateTime, task.recurrenceWeekdays);
  }

  DateTime? _nextCustomWeekdayFrom(DateTime dateTime, List<int> weekdays) {
    if (weekdays.isEmpty) return null;

    for (var daysToAdd = 1; daysToAdd <= 7; daysToAdd++) {
      final candidate = _withSameTime(dateTime, daysToAdd: daysToAdd);
      if (weekdays.contains(candidate.weekday)) {
        return candidate;
      }
    }

    return null;
  }

  DateTime _withSameTime(DateTime dateTime, {required int daysToAdd}) {
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day + daysToAdd,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
      dateTime.millisecond,
      dateTime.microsecond,
    );
  }

  String _newTaskId(DateTime createdAt) {
    return 'task-${createdAt.microsecondsSinceEpoch}-${_idSequence++}';
  }
}

var _idSequence = 0;
