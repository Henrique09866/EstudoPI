class MockExamSubjectResult {
  const MockExamSubjectResult({
    required this.subject,
    required this.totalQuestions,
    required this.correctAnswers,
  }) : assert(subject != ''),
       assert(totalQuestions > 0),
       assert(correctAnswers >= 0 && correctAnswers <= totalQuestions);

  final String subject;
  final int totalQuestions;
  final int correctAnswers;

  double get accuracy => correctAnswers / totalQuestions;

  Map<String, dynamic> toMap() => {
    'subject': subject,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
  };

  factory MockExamSubjectResult.fromMap(Map<String, dynamic> map) {
    final subject = map['subject'];
    final totalQuestions = map['totalQuestions'];
    final correctAnswers = map['correctAnswers'];
    if (subject is! String ||
        subject.trim().isEmpty ||
        totalQuestions is! num ||
        correctAnswers is! num ||
        totalQuestions <= 0 ||
        correctAnswers < 0 ||
        correctAnswers > totalQuestions) {
      throw const FormatException('Resultado por matéria inválido.');
    }
    return MockExamSubjectResult(
      subject: subject.trim(),
      totalQuestions: totalQuestions.toInt(),
      correctAnswers: correctAnswers.toInt(),
    );
  }
}

class MockExam {
  MockExam({
    required this.id,
    required String title,
    this.studyPlan,
    required this.takenAt,
    required this.totalQuestions,
    required this.correctAnswers,
    this.duration = Duration.zero,
    List<MockExamSubjectResult> subjectResults = const [],
    this.notes,
  }) : assert(id != ''),
       assert(title != ''),
       assert(totalQuestions > 0),
       assert(correctAnswers >= 0 && correctAnswers <= totalQuestions),
       assert(!duration.isNegative),
       title = title.trim(),
       subjectResults = List.unmodifiable(subjectResults);

  final String id;
  final String title;
  final String? studyPlan;
  final DateTime takenAt;
  final int totalQuestions;
  final int correctAnswers;
  final Duration duration;
  final List<MockExamSubjectResult> subjectResults;
  final String? notes;

  double get accuracy => correctAnswers / totalQuestions;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'studyPlan': studyPlan,
    'takenAt': takenAt.toIso8601String(),
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'durationSeconds': duration.inSeconds,
    'subjectResults': subjectResults.map((result) => result.toMap()).toList(),
    'notes': notes,
  };

  factory MockExam.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final title = map['title'];
    final takenAt = map['takenAt'];
    final totalQuestions = map['totalQuestions'];
    final correctAnswers = map['correctAnswers'];
    final durationSeconds = map['durationSeconds'];
    final studyPlan = map['studyPlan'];
    final notes = map['notes'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        takenAt is! String ||
        totalQuestions is! num ||
        correctAnswers is! num ||
        durationSeconds is! num ||
        totalQuestions <= 0 ||
        correctAnswers < 0 ||
        correctAnswers > totalQuestions ||
        durationSeconds < 0 ||
        (studyPlan != null && studyPlan is! String) ||
        (notes != null && notes is! String)) {
      throw const FormatException('Simulado inválido.');
    }
    final rawSubjects = map['subjectResults'];
    final subjectResults = <MockExamSubjectResult>[];
    if (rawSubjects is Iterable) {
      for (final value in rawSubjects.whereType<Map>()) {
        subjectResults.add(
          MockExamSubjectResult.fromMap(Map<String, dynamic>.from(value)),
        );
      }
    }
    final normalizedPlan = studyPlan?.trim();
    final normalizedNotes = notes?.trim();
    return MockExam(
      id: id,
      title: title,
      studyPlan: normalizedPlan == null || normalizedPlan.isEmpty
          ? null
          : normalizedPlan,
      takenAt: DateTime.parse(takenAt),
      totalQuestions: totalQuestions.toInt(),
      correctAnswers: correctAnswers.toInt(),
      duration: Duration(seconds: durationSeconds.toInt()),
      subjectResults: subjectResults,
      notes: normalizedNotes == null || normalizedNotes.isEmpty
          ? null
          : normalizedNotes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockExam &&
          id == other.id &&
          title == other.title &&
          studyPlan == other.studyPlan &&
          takenAt == other.takenAt &&
          totalQuestions == other.totalQuestions &&
          correctAnswers == other.correctAnswers &&
          duration == other.duration &&
          notes == other.notes &&
          _sameSubjects(subjectResults, other.subjectResults);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    studyPlan,
    takenAt,
    totalQuestions,
    correctAnswers,
    duration,
    notes,
    Object.hashAll(
      subjectResults.map(
        (result) => Object.hash(
          result.subject,
          result.totalQuestions,
          result.correctAnswers,
        ),
      ),
    ),
  );

  static bool _sameSubjects(
    List<MockExamSubjectResult> first,
    List<MockExamSubjectResult> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      final firstResult = first[index];
      final secondResult = second[index];
      if (firstResult.subject != secondResult.subject ||
          firstResult.totalQuestions != secondResult.totalQuestions ||
          firstResult.correctAnswers != secondResult.correctAnswers) {
        return false;
      }
    }
    return true;
  }
}
