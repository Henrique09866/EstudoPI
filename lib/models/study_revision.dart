import 'dart:convert';

class StudyRevision {
  StudyRevision({
    required this.id,
    required this.subject,
    this.studyPlan,
    required this.scheduledFor,
    this.suggestedMinutes = 15,
    this.completedAt,
  }) : assert(subject != ''),
       assert(suggestedMinutes > 0);

  final String id;
  final String subject;
  final String? studyPlan;
  final DateTime scheduledFor;
  final int suggestedMinutes;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  static String idFor({
    required String subject,
    required String? studyPlan,
    required DateTime scheduledFor,
  }) {
    final date = DateTime(
      scheduledFor.year,
      scheduledFor.month,
      scheduledFor.day,
    ).toIso8601String();
    final plan = studyPlan?.trim().toLowerCase() ?? '';
    final value = '$plan\u0000${subject.trim().toLowerCase()}\u0000$date';
    return 'revision-${base64Url.encode(utf8.encode(value))}';
  }

  StudyRevision copyWith({
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => StudyRevision(
    id: id,
    subject: subject,
    studyPlan: studyPlan,
    scheduledFor: scheduledFor,
    suggestedMinutes: suggestedMinutes,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'subject': subject,
    'studyPlan': studyPlan,
    'scheduledFor': scheduledFor.toIso8601String(),
    'suggestedMinutes': suggestedMinutes,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory StudyRevision.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final subject = map['subject'];
    final scheduledFor = map['scheduledFor'];
    final suggestedMinutes = map['suggestedMinutes'];
    final studyPlan = map['studyPlan'];
    final completedAt = map['completedAt'];
    if (id is! String ||
        id.isEmpty ||
        subject is! String ||
        subject.trim().isEmpty ||
        scheduledFor is! String ||
        suggestedMinutes is! num ||
        suggestedMinutes <= 0 ||
        (studyPlan != null && studyPlan is! String) ||
        (completedAt != null && completedAt is! String)) {
      throw const FormatException('Revisão de estudo inválida.');
    }
    final normalizedPlan = studyPlan?.trim();
    return StudyRevision(
      id: id,
      subject: subject.trim(),
      studyPlan: normalizedPlan == null || normalizedPlan.isEmpty
          ? null
          : normalizedPlan,
      scheduledFor: DateTime.parse(scheduledFor),
      suggestedMinutes: suggestedMinutes.toInt(),
      completedAt: completedAt == null ? null : DateTime.parse(completedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyRevision &&
          id == other.id &&
          subject == other.subject &&
          studyPlan == other.studyPlan &&
          scheduledFor == other.scheduledFor &&
          suggestedMinutes == other.suggestedMinutes &&
          completedAt == other.completedAt;

  @override
  int get hashCode => Object.hash(
    id,
    subject,
    studyPlan,
    scheduledFor,
    suggestedMinutes,
    completedAt,
  );
}
