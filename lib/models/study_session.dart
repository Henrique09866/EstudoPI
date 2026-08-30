enum StudySessionType { pomodoro, freeTimer }

class StudySession {
  StudySession({
    required this.id,
    this.subject,
    this.studyPlan,
    this.notes,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.type,
  }) : assert(!endedAt.isBefore(startedAt)),
       assert(!duration.isNegative);

  final String id;
  final String? subject;

  /// Prova, concurso ou objetivo ao qual a sessão pertence.
  ///
  /// `null` representa uma sessão geral e também mantém compatibilidade com
  /// as sessões salvas antes da criação da Área de estudos.
  final String? studyPlan;
  final String? notes;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final StudySessionType type;

  Map<String, dynamic> toMap() => {
    'id': id,
    'subject': subject,
    'studyPlan': studyPlan,
    'notes': notes,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'type': type.name,
  };

  factory StudySession.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final startedAt = map['startedAt'];
    final endedAt = map['endedAt'];
    final durationSeconds = map['durationSeconds'];
    if (id is! String ||
        id.trim().isEmpty ||
        startedAt is! String ||
        endedAt is! String ||
        durationSeconds is! num ||
        durationSeconds.isNegative) {
      throw const FormatException('Sessão de estudo inválida.');
    }

    final parsedStartedAt = DateTime.parse(startedAt);
    final parsedEndedAt = DateTime.parse(endedAt);
    if (parsedEndedAt.isBefore(parsedStartedAt)) {
      throw const FormatException('Datas da sessão inválidas.');
    }

    return StudySession(
      id: id,
      subject: _optionalSubject(map['subject']),
      studyPlan: _optionalSubject(map['studyPlan']),
      notes: _optionalNotes(map['notes']),
      startedAt: parsedStartedAt,
      endedAt: parsedEndedAt,
      duration: Duration(seconds: durationSeconds.toInt()),
      type: _typeFromName(map['type']),
    );
  }

  StudySession copyWith({
    String? id,
    Object? subject = _sentinel,
    Object? studyPlan = _sentinel,
    Object? notes = _sentinel,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    StudySessionType? type,
  }) => StudySession(
    id: id ?? this.id,
    subject: identical(subject, _sentinel) ? this.subject : subject as String?,
    studyPlan: identical(studyPlan, _sentinel)
        ? this.studyPlan
        : studyPlan as String?,
    notes: identical(notes, _sentinel) ? this.notes : notes as String?,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    duration: duration ?? this.duration,
    type: type ?? this.type,
  );

  static const _sentinel = Object();

  static String? _optionalSubject(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Matéria inválida.');
    final subject = value.trim();
    return subject.isEmpty ? null : subject;
  }

  static String? _optionalNotes(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Nota inválida.');
    final notes = value.trim();
    return notes.isEmpty ? null : notes;
  }

  static StudySessionType _typeFromName(Object? value) {
    if (value is String) {
      for (final type in StudySessionType.values) {
        if (type.name == value) return type;
      }
    }
    return StudySessionType.freeTimer;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudySession &&
          id == other.id &&
          subject == other.subject &&
          studyPlan == other.studyPlan &&
          notes == other.notes &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt &&
          duration == other.duration &&
          type == other.type;

  @override
  int get hashCode => Object.hash(
    id,
    subject,
    studyPlan,
    notes,
    startedAt,
    endedAt,
    duration,
    type,
  );
}
