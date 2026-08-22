enum TaskPriority { low, medium, high }

enum TaskCategory { study, assignment, exam, personal, other }

enum TaskRecurrence { none, daily, weekly, customWeekdays }

extension TaskRecurrenceLabel on TaskRecurrence {
  String get label {
    return switch (this) {
      TaskRecurrence.none => 'Não repetir',
      TaskRecurrence.daily => 'Todos os dias',
      TaskRecurrence.weekly => 'Toda semana',
      TaskRecurrence.customWeekdays => 'Dias específicos',
    };
  }
}

/// Returns the short Portuguese label for [DateTime.weekday] values (1–7).
String weekdayShortLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Seg',
    DateTime.tuesday => 'Ter',
    DateTime.wednesday => 'Qua',
    DateTime.thursday => 'Qui',
    DateTime.friday => 'Sex',
    DateTime.saturday => 'Sáb',
    DateTime.sunday => 'Dom',
    _ => '',
  };
}

extension TaskCategoryLabel on TaskCategory {
  String get label {
    return switch (this) {
      TaskCategory.study => 'Estudo',
      TaskCategory.assignment => 'Trabalho',
      TaskCategory.exam => 'Prova',
      TaskCategory.personal => 'Pessoal',
      TaskCategory.other => 'Outro',
    };
  }
}

enum ReminderOffset {
  atTime(Duration.zero),
  tenMinutes(Duration(minutes: 10)),
  thirtyMinutes(Duration(minutes: 30)),
  oneHour(Duration(hours: 1));

  const ReminderOffset(this.duration);

  final Duration duration;
}

const _copyWithSentinel = Object();

class Task {
  Task({
    required this.id,
    required String title,
    this.description,
    this.subject,
    required this.dateTime,
    required this.priority,
    this.category = TaskCategory.other,
    this.reminderOffset = ReminderOffset.atTime,
    this.recurrence = TaskRecurrence.none,
    List<int> recurrenceWeekdays = const [],
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  }) : title = _validateTitle(title),
       recurrenceWeekdays = List.unmodifiable(
         _normalizeWeekdays(recurrenceWeekdays),
       );

  final String id;
  final String title;
  final String? description;
  final String? subject;
  final DateTime dateTime;
  final TaskPriority priority;
  final TaskCategory category;
  final ReminderOffset reminderOffset;
  final TaskRecurrence recurrence;

  /// Weekday values follow [DateTime.monday] (1) through [DateTime.sunday] (7).
  final List<int> recurrenceWeekdays;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isPending => !isCompleted;

  bool get isOverdue => !isCompleted && dateTime.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'dateTime': dateTime.toIso8601String(),
      'priority': priority.name,
      'category': category.name,
      'reminderOffset': reminderOffset.name,
      'recurrence': recurrence.name,
      'recurrenceWeekdays': List<int>.of(recurrenceWeekdays),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      subject: map['subject'] as String?,
      dateTime: DateTime.parse(map['dateTime'] as String),
      priority: _priorityFromName(map['priority'] as String?),
      category: _categoryFromName(map['category'] as String?),
      reminderOffset: _reminderOffsetFromName(map['reminderOffset'] as String?),
      recurrence: _recurrenceFromName(map['recurrence'] as String?),
      recurrenceWeekdays: _weekdaysFromMap(map['recurrenceWeekdays']),
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: _dateTimeOrNull(map['completedAt']),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Task copyWith({
    String? id,
    String? title,
    Object? description = _copyWithSentinel,
    Object? subject = _copyWithSentinel,
    DateTime? dateTime,
    TaskPriority? priority,
    TaskCategory? category,
    ReminderOffset? reminderOffset,
    TaskRecurrence? recurrence,
    List<int>? recurrenceWeekdays,
    bool? isCompleted,
    Object? completedAt = _copyWithSentinel,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: identical(description, _copyWithSentinel)
          ? this.description
          : description as String?,
      subject: identical(subject, _copyWithSentinel)
          ? this.subject
          : subject as String?,
      dateTime: dateTime ?? this.dateTime,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      reminderOffset: reminderOffset ?? this.reminderOffset,
      recurrence: recurrence ?? this.recurrence,
      recurrenceWeekdays: recurrenceWeekdays ?? this.recurrenceWeekdays,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: identical(completedAt, _copyWithSentinel)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _validateTitle(String title) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title cannot be empty.');
    }

    return title;
  }

  static TaskPriority _priorityFromName(String? name) {
    for (final priority in TaskPriority.values) {
      if (priority.name == name) {
        return priority;
      }
    }

    return TaskPriority.medium;
  }

  static ReminderOffset _reminderOffsetFromName(String? name) {
    for (final reminderOffset in ReminderOffset.values) {
      if (reminderOffset.name == name) {
        return reminderOffset;
      }
    }

    return ReminderOffset.atTime;
  }

  static TaskCategory _categoryFromName(String? name) {
    for (final category in TaskCategory.values) {
      if (category.name == name) {
        return category;
      }
    }

    return TaskCategory.other;
  }

  static TaskRecurrence _recurrenceFromName(String? name) {
    for (final recurrence in TaskRecurrence.values) {
      if (recurrence.name == name) {
        return recurrence;
      }
    }

    return TaskRecurrence.none;
  }

  static List<int> _weekdaysFromMap(Object? value) {
    if (value is! List) return const [];

    return value.whereType<num>().map((weekday) => weekday.toInt()).toList();
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static List<int> _normalizeWeekdays(Iterable<int> weekdays) {
    final normalized =
        weekdays
            .where(
              (weekday) =>
                  weekday >= DateTime.monday && weekday <= DateTime.sunday,
            )
            .toSet()
            .toList()
          ..sort();
    return normalized;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Task &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            title == other.title &&
            description == other.description &&
            subject == other.subject &&
            dateTime == other.dateTime &&
            priority == other.priority &&
            category == other.category &&
            reminderOffset == other.reminderOffset &&
            recurrence == other.recurrence &&
            _sameWeekdays(recurrenceWeekdays, other.recurrenceWeekdays) &&
            isCompleted == other.isCompleted &&
            completedAt == other.completedAt &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      description,
      subject,
      dateTime,
      priority,
      category,
      reminderOffset,
      recurrence,
      Object.hashAll(recurrenceWeekdays),
      isCompleted,
      completedAt,
      createdAt,
    );
  }

  static bool _sameWeekdays(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
