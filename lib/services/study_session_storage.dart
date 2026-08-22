import '../models/study_session.dart';

abstract class StudySessionStorage {
  Future<List<StudySession>> getSessions();

  Future<void> saveSession(StudySession session);

  Future<void> deleteSession(String id);

  Future<int> getDailyGoalMinutes();

  Future<void> saveDailyGoalMinutes(int minutes);
}
