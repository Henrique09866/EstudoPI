import '../models/study_cycle_subject.dart';
import '../models/mock_exam.dart';
import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../models/study_revision.dart';
import 'study_timer_controller.dart';

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

  Future<void> deleteRevision(String revisionId) async {}

  /// Matérias e marcações manuais do ciclo de estudos. As implementações
  /// antigas podem deixá-las vazias sem afetar o restante da Área de estudos.
  Future<List<StudyCycleSubject>> getCycleSubjects() async => const [];

  Future<void> saveCycleSubject(StudyCycleSubject subject) async {}

  Future<void> deleteCycleSubject(String subjectId) async {}

  Future<List<StudyCycleCheckIn>> getCycleCheckIns() async => const [];

  Future<void> saveCycleCheckIn(StudyCycleCheckIn checkIn) async {}

  Future<void> deleteCycleCheckIn(String checkInId) async {}

  Future<List<MockExam>> getMockExams() async => const [];

  Future<void> saveMockExam(MockExam exam) async {}

  Future<void> deleteMockExam(String examId) async {}

  /// Atalhos de matérias usados na aba de cronômetro rápido.
  Future<List<String>> getQuickSubjects() async => const [];

  Future<void> saveQuickSubject(String subject) async {}

  /// A sessão em andamento fica separada do histórico para que o botão Play
  /// possa continuar exatamente o estudo que estava aberto antes.
  Future<ActiveStudyTimer?> getActiveStudyTimer() async => null;

  Future<void> saveActiveStudyTimer(ActiveStudyTimer timer) async {}

  Future<void> clearActiveStudyTimer() async {}

  /// Substitui todos os dados de estudo por uma cópia sincronizada da conta.
  Future<void> replaceAllStudyData({
    required List<StudySession> sessions,
    required int dailyGoalMinutes,
    required List<StudyWeeklyGoal> weeklyGoals,
    required List<StudyRevision> revisions,
    required List<StudyCycleSubject> cycleSubjects,
    required List<StudyCycleCheckIn> cycleCheckIns,
    required List<MockExam> mockExams,
  }) async {
    for (final session in await getSessions()) {
      await deleteSession(session.id);
    }
    for (final goal in await getWeeklyGoals()) {
      await deleteWeeklyGoal(goal.id);
    }
    for (final revision in await getRevisions()) {
      await deleteRevision(revision.id);
    }
    for (final checkIn in await getCycleCheckIns()) {
      await deleteCycleCheckIn(checkIn.id);
    }
    for (final subject in await getCycleSubjects()) {
      await deleteCycleSubject(subject.id);
    }
    for (final exam in await getMockExams()) {
      await deleteMockExam(exam.id);
    }

    for (final session in sessions) {
      await saveSession(session);
    }
    await saveDailyGoalMinutes(dailyGoalMinutes);
    for (final goal in weeklyGoals) {
      await saveWeeklyGoal(goal);
    }
    for (final revision in revisions) {
      await saveRevision(revision);
    }
    for (final subject in cycleSubjects) {
      await saveCycleSubject(subject);
    }
    for (final checkIn in cycleCheckIns) {
      await saveCycleCheckIn(checkIn);
    }
    for (final exam in mockExams) {
      await saveMockExam(exam);
    }
  }
}
