import '../models/study_revision.dart';

abstract class StudyRevisionReminderScheduler {
  Future<void> scheduleStudyRevisionReminder(StudyRevision revision);

  Future<void> cancelStudyRevisionReminder(String revisionId);

  Future<void> reconcileStudyRevisionReminders(
    Iterable<StudyRevision> revisions,
  );
}
