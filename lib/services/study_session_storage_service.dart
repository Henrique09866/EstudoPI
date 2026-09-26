import 'package:hive_flutter/hive_flutter.dart';

import '../models/study_cycle_subject.dart';
import '../models/mock_exam.dart';
import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../models/study_revision.dart';
import 'study_session_storage.dart';
import 'study_timer_controller.dart';

class StudySessionStorageService extends StudySessionStorage {
  StudySessionStorageService(this._sessionsBox, this._settingsBox);

  static const sessionsBoxName = 'study_sessions';
  static const settingsBoxName = 'study_settings';
  static const _dailyGoalKey = 'daily_goal_minutes';
  static const _weeklyGoalsKey = 'weekly_study_goals_v1';
  static const _revisionsKey = 'study_revisions_v1';
  static const _cycleSubjectsKey = 'study_cycle_subjects_v1';
  static const _cycleCheckInsKey = 'study_cycle_check_ins_v1';
  static const _mockExamsKey = 'mock_exams_v1';
  static const _quickSubjectsKey = 'quick_study_subjects_v1';
  static const _activeStudyTimerKey = 'active_study_timer_v1';
  static const defaultDailyGoalMinutes = 60;

  final Box<dynamic> _sessionsBox;
  final Box<dynamic> _settingsBox;

  static Future<void> init() async {
    await Hive.openBox<dynamic>(sessionsBoxName);
    await Hive.openBox<dynamic>(settingsBoxName);
  }

  factory StudySessionStorageService.instance() => StudySessionStorageService(
    Hive.box<dynamic>(sessionsBoxName),
    Hive.box<dynamic>(settingsBoxName),
  );

  @override
  Future<List<StudySession>> getSessions() async {
    final sessions = <StudySession>[];
    for (final value in _sessionsBox.values.whereType<Map>()) {
      try {
        sessions.add(StudySession.fromMap(Map<String, dynamic>.from(value)));
      } catch (_) {
        continue;
      }
    }
    return sessions;
  }

  @override
  Future<void> saveSession(StudySession session) =>
      _sessionsBox.put(session.id, session.toMap());

  @override
  Future<void> deleteSession(String id) => _sessionsBox.delete(id);

  @override
  Future<int> getDailyGoalMinutes() async {
    final value = _settingsBox.get(_dailyGoalKey);
    if (value is num && value > 0) return value.toInt();
    return defaultDailyGoalMinutes;
  }

  @override
  Future<void> saveDailyGoalMinutes(int minutes) async {
    if (minutes <= 0) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'A meta deve ser positiva.',
      );
    }
    await _settingsBox.put(_dailyGoalKey, minutes);
  }

  @override
  Future<List<StudyWeeklyGoal>> getWeeklyGoals() async {
    final storedGoals = _settingsBox.get(_weeklyGoalsKey);
    if (storedGoals is! Iterable) return const [];
    final goals = <StudyWeeklyGoal>[];
    for (final value in storedGoals.whereType<Map>()) {
      try {
        goals.add(StudyWeeklyGoal.fromMap(Map<String, dynamic>.from(value)));
      } catch (_) {
        continue;
      }
    }
    goals.sort((first, second) {
      final planOrder = (first.studyPlan ?? '').compareTo(
        second.studyPlan ?? '',
      );
      return planOrder != 0
          ? planOrder
          : first.subject.compareTo(second.subject);
    });
    return List.unmodifiable(goals);
  }

  @override
  Future<void> saveWeeklyGoal(StudyWeeklyGoal goal) async {
    final goals = await getWeeklyGoals();
    final updatedGoals = [
      ...goals.where((current) => current.id != goal.id),
      goal,
    ];
    await _settingsBox.put(
      _weeklyGoalsKey,
      updatedGoals.map((current) => current.toMap()).toList(),
    );
  }

  @override
  Future<void> deleteWeeklyGoal(String goalId) async {
    final goals = await getWeeklyGoals();
    await _settingsBox.put(
      _weeklyGoalsKey,
      goals
          .where((goal) => goal.id != goalId)
          .map((goal) => goal.toMap())
          .toList(),
    );
  }

  @override
  Future<List<StudyRevision>> getRevisions() async {
    final storedRevisions = _settingsBox.get(_revisionsKey);
    if (storedRevisions is! Iterable) return const [];
    final revisions = <StudyRevision>[];
    for (final value in storedRevisions.whereType<Map>()) {
      try {
        revisions.add(StudyRevision.fromMap(Map<String, dynamic>.from(value)));
      } catch (_) {
        continue;
      }
    }
    revisions.sort(
      (first, second) => first.scheduledFor.compareTo(second.scheduledFor),
    );
    return List.unmodifiable(revisions);
  }

  @override
  Future<void> saveRevision(StudyRevision revision) async {
    final revisions = await getRevisions();
    final updatedRevisions = [
      ...revisions.where((current) => current.id != revision.id),
      revision,
    ];
    await _settingsBox.put(
      _revisionsKey,
      updatedRevisions.map((current) => current.toMap()).toList(),
    );
  }

  @override
  Future<void> deleteRevision(String revisionId) async {
    final revisions = await getRevisions();
    await _settingsBox.put(
      _revisionsKey,
      revisions
          .where((revision) => revision.id != revisionId)
          .map((revision) => revision.toMap())
          .toList(),
    );
  }

  @override
  Future<List<StudyCycleSubject>> getCycleSubjects() async {
    final storedSubjects = _settingsBox.get(_cycleSubjectsKey);
    if (storedSubjects is! Iterable) return const [];
    final subjects = <StudyCycleSubject>[];
    for (final value in storedSubjects.whereType<Map>()) {
      try {
        subjects.add(
          StudyCycleSubject.fromMap(Map<String, dynamic>.from(value)),
        );
      } catch (_) {
        continue;
      }
    }
    subjects.sort((first, second) => first.name.compareTo(second.name));
    return List.unmodifiable(subjects);
  }

  @override
  Future<void> saveCycleSubject(StudyCycleSubject subject) async {
    final subjects = await getCycleSubjects();
    final updatedSubjects = [
      ...subjects.where((current) => current.id != subject.id),
      subject,
    ]..sort((first, second) => first.name.compareTo(second.name));
    await _settingsBox.put(
      _cycleSubjectsKey,
      updatedSubjects.map((current) => current.toMap()).toList(),
    );
  }

  @override
  Future<void> deleteCycleSubject(String subjectId) async {
    final subjects = await getCycleSubjects();
    final checkIns = await getCycleCheckIns();
    await _settingsBox.put(
      _cycleSubjectsKey,
      subjects
          .where((subject) => subject.id != subjectId)
          .map((subject) => subject.toMap())
          .toList(),
    );
    await _settingsBox.put(
      _cycleCheckInsKey,
      checkIns
          .where((checkIn) => checkIn.subjectId != subjectId)
          .map((checkIn) => checkIn.toMap())
          .toList(),
    );
  }

  @override
  Future<List<StudyCycleCheckIn>> getCycleCheckIns() async {
    final storedCheckIns = _settingsBox.get(_cycleCheckInsKey);
    if (storedCheckIns is! Iterable) return const [];
    final checkIns = <StudyCycleCheckIn>[];
    for (final value in storedCheckIns.whereType<Map>()) {
      try {
        checkIns.add(
          StudyCycleCheckIn.fromMap(Map<String, dynamic>.from(value)),
        );
      } catch (_) {
        continue;
      }
    }
    checkIns.sort((first, second) => first.day.compareTo(second.day));
    return List.unmodifiable(checkIns);
  }

  @override
  Future<void> saveCycleCheckIn(StudyCycleCheckIn checkIn) async {
    final checkIns = await getCycleCheckIns();
    final updatedCheckIns = [
      ...checkIns.where((current) => current.id != checkIn.id),
      checkIn,
    ];
    await _settingsBox.put(
      _cycleCheckInsKey,
      updatedCheckIns.map((current) => current.toMap()).toList(),
    );
  }

  @override
  Future<void> deleteCycleCheckIn(String checkInId) async {
    final checkIns = await getCycleCheckIns();
    await _settingsBox.put(
      _cycleCheckInsKey,
      checkIns
          .where((checkIn) => checkIn.id != checkInId)
          .map((checkIn) => checkIn.toMap())
          .toList(),
    );
  }

  @override
  Future<List<MockExam>> getMockExams() async {
    final storedExams = _settingsBox.get(_mockExamsKey);
    if (storedExams is! Iterable) return const [];
    final exams = <MockExam>[];
    for (final value in storedExams.whereType<Map>()) {
      try {
        exams.add(MockExam.fromMap(Map<String, dynamic>.from(value)));
      } catch (_) {
        continue;
      }
    }
    exams.sort((first, second) => second.takenAt.compareTo(first.takenAt));
    return List.unmodifiable(exams);
  }

  @override
  Future<void> saveMockExam(MockExam exam) async {
    final exams = await getMockExams();
    final updated = [...exams.where((current) => current.id != exam.id), exam]
      ..sort((first, second) => second.takenAt.compareTo(first.takenAt));
    await _settingsBox.put(
      _mockExamsKey,
      updated.map((current) => current.toMap()).toList(),
    );
  }

  @override
  Future<void> deleteMockExam(String examId) async {
    final exams = await getMockExams();
    await _settingsBox.put(
      _mockExamsKey,
      exams
          .where((exam) => exam.id != examId)
          .map((exam) => exam.toMap())
          .toList(),
    );
  }

  @override
  Future<List<String>> getQuickSubjects() async {
    final storedSubjects = _settingsBox.get(_quickSubjectsKey);
    if (storedSubjects is! Iterable) return const [];
    final subjects =
        storedSubjects
            .whereType<String>()
            .map((subject) => subject.trim())
            .where((subject) => subject.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (first, second) =>
                first.toLowerCase().compareTo(second.toLowerCase()),
          );
    return List.unmodifiable(subjects);
  }

  @override
  Future<void> saveQuickSubject(String subject) async {
    final normalized = subject.trim();
    if (normalized.isEmpty) return;
    final existing = await getQuickSubjects();
    final updated =
        <String>[
          ...existing.where(
            (current) => current.toLowerCase() != normalized.toLowerCase(),
          ),
          normalized,
        ]..sort(
          (first, second) =>
              first.toLowerCase().compareTo(second.toLowerCase()),
        );
    await _settingsBox.put(_quickSubjectsKey, updated);
  }

  @override
  Future<ActiveStudyTimer?> getActiveStudyTimer() async {
    final storedTimer = _settingsBox.get(_activeStudyTimerKey);
    if (storedTimer is! Map) return null;
    try {
      return ActiveStudyTimer.fromMap(Map<String, dynamic>.from(storedTimer));
    } catch (_) {
      // Uma cópia antiga ou incompleta nunca deve bloquear a Área de estudos.
      return null;
    }
  }

  @override
  Future<void> saveActiveStudyTimer(ActiveStudyTimer timer) =>
      _settingsBox.put(_activeStudyTimerKey, timer.toMap());

  @override
  Future<void> clearActiveStudyTimer() =>
      _settingsBox.delete(_activeStudyTimerKey);
}
