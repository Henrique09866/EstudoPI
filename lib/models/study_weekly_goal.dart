import 'dart:convert';

class StudyWeeklyGoal {
  StudyWeeklyGoal({
    required this.studyPlan,
    required this.subject,
    required this.targetMinutes,
  }) : assert(subject != ''),
       assert(targetMinutes > 0);

  /// `null` agrupa metas de estudo geral, sem prova ou concurso definido.
  final String? studyPlan;
  final String subject;
  final int targetMinutes;

  String get id => idFor(studyPlan: studyPlan, subject: subject);

  static String idFor({required String? studyPlan, required String subject}) {
    final normalizedPlan = studyPlan?.trim().toLowerCase() ?? '';
    final normalizedSubject = subject.trim().toLowerCase();
    return base64Url.encode(
      utf8.encode('$normalizedPlan\u0000$normalizedSubject'),
    );
  }

  Map<String, dynamic> toMap() => {
    'studyPlan': studyPlan,
    'subject': subject,
    'targetMinutes': targetMinutes,
  };

  factory StudyWeeklyGoal.fromMap(Map<String, dynamic> map) {
    final subject = map['subject'];
    final targetMinutes = map['targetMinutes'];
    if (subject is! String ||
        subject.trim().isEmpty ||
        targetMinutes is! num ||
        targetMinutes <= 0) {
      throw const FormatException('Meta semanal inválida.');
    }
    final studyPlan = map['studyPlan'];
    if (studyPlan != null && studyPlan is! String) {
      throw const FormatException('Objetivo da meta inválido.');
    }
    final normalizedPlan = studyPlan?.trim();
    return StudyWeeklyGoal(
      studyPlan: normalizedPlan == null || normalizedPlan.isEmpty
          ? null
          : normalizedPlan,
      subject: subject.trim(),
      targetMinutes: targetMinutes.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyWeeklyGoal &&
          studyPlan == other.studyPlan &&
          subject == other.subject &&
          targetMinutes == other.targetMinutes;

  @override
  int get hashCode => Object.hash(studyPlan, subject, targetMinutes);
}
