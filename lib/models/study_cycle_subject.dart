class StudyCycleSubject {
  const StudyCycleSubject({
    required this.id,
    required this.name,
    required this.colorIndex,
  }) : assert(id != ''),
       assert(name != ''),
       assert(colorIndex >= 0);

  final String id;
  final String name;
  final int colorIndex;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
  };

  factory StudyCycleSubject.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = map['name'];
    final colorIndex = map['colorIndex'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        colorIndex is! num ||
        colorIndex < 0) {
      throw const FormatException('Matéria do ciclo inválida.');
    }
    return StudyCycleSubject(
      id: id.trim(),
      name: name.trim(),
      colorIndex: colorIndex.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyCycleSubject &&
          id == other.id &&
          name == other.name &&
          colorIndex == other.colorIndex;

  @override
  int get hashCode => Object.hash(id, name, colorIndex);
}

class StudyCycleCheckIn {
  StudyCycleCheckIn({required this.subjectId, required DateTime day})
    : day = DateTime(day.year, day.month, day.day);

  final String subjectId;
  final DateTime day;

  String get id => idFor(subjectId: subjectId, day: day);

  static String idFor({required String subjectId, required DateTime day}) =>
      '$subjectId@${StudyCycleCalendar.dayKey(day)}';

  Map<String, dynamic> toMap() => {
    'subjectId': subjectId,
    'day': day.millisecondsSinceEpoch,
  };

  factory StudyCycleCheckIn.fromMap(Map<String, dynamic> map) {
    final subjectId = map['subjectId'];
    final day = map['day'];
    if (subjectId is! String || subjectId.trim().isEmpty || day is! num) {
      throw const FormatException('Marcação do ciclo inválida.');
    }
    return StudyCycleCheckIn(
      subjectId: subjectId.trim(),
      day: DateTime.fromMillisecondsSinceEpoch(day.toInt()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyCycleCheckIn &&
          subjectId == other.subjectId &&
          day == other.day;

  @override
  int get hashCode => Object.hash(subjectId, day);
}

class StudyCycleCalendar {
  const StudyCycleCalendar._();

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime weekStart(DateTime value) {
    final day = dateOnly(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static List<DateTime> weekDays(DateTime value) {
    final start = weekStart(value);
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  static String dayKey(DateTime value) {
    final day = dateOnly(value);
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }
}
