import '../models/study_cycle_subject.dart';
import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../models/study_revision.dart';

abstract class StudySessionStorage {
  Future<List<StudySession>> getSessions();

  Future<void> saveSession(StudySession session);

  Future<void> deleteSession(String id);

  Future<int> getDailyGoalMinutes();

  Future<void> saveDailyGoalMinutes(int minutes);

  /// Metas por matéria para a semana atual. Implementações antigas podem
  /// ignorá-las sem impedir o cronômetro ou o histórico de funcionar.
  Future<List<StudyWeeklyGoal>> getWeeklyGoals() async => const [];

  Future<void> saveWeeklyGoal(StudyWeeklyGoal goal) async {}

  Future<void> deleteWeeklyGoal(String goalId) async {}

  Future<List<StudyRevision>> getRevisions() async => const [];

  Future<void> saveRevision(StudyRevision revision) async {}

  /// Matérias e marcações manuais do ciclo de estudos. As implementações
  /// antigas podem deixá-las vazias sem afetar o restante da Área de estudos.
  Future<List<StudyCycleSubject>> getCycleSubjects() async => const [];

  Future<void> saveCycleSubject(StudyCycleSubject subject) async {}

  Future<void> deleteCycleSubject(String subjectId) async {}

  Future<List<StudyCycleCheckIn>> getCycleCheckIns() async => const [];

  Future<void> saveCycleCheckIn(StudyCycleCheckIn checkIn) async {}

  Future<void> deleteCycleCheckIn(String checkInId) async {}
}
