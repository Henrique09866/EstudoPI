import '../models/study_revision.dart';
import '../models/study_session.dart';

class StudyRevisionPlanner {
  const StudyRevisionPlanner();

  static const intervals = [
    Duration(days: 1),
    Duration(days: 7),
    Duration(days: 30),
  ];
  static const suggestedMinutes = 15;

  List<StudyRevision> revisionsFor(StudySession session) {
    final subject = session.subject?.trim();
    if (subject == null || subject.isEmpty) return const [];
    final studiedOn = DateTime(
      session.endedAt.year,
      session.endedAt.month,
      session.endedAt.day,
    );
    return intervals
        .map((interval) {
          final scheduledFor = studiedOn.add(interval);
          return StudyRevision(
            id: StudyRevision.idFor(
              subject: subject,
              studyPlan: session.studyPlan,
              scheduledFor: scheduledFor,
            ),
            subject: subject,
            studyPlan: session.studyPlan,
            scheduledFor: scheduledFor,
            suggestedMinutes: suggestedMinutes,
          );
        })
        .toList(growable: false);
  }

  List<StudyRevision> pendingForDay(
    Iterable<StudyRevision> revisions,
    DateTime day,
  ) {
    final endOfDay = DateTime(day.year, day.month, day.day + 1);
    final result =
        revisions
            .where(
              (revision) =>
                  !revision.isCompleted &&
                  revision.scheduledFor.isBefore(endOfDay),
            )
            .toList()
          ..sort((first, second) {
            final dateOrder = first.scheduledFor.compareTo(second.scheduledFor);
            if (dateOrder != 0) return dateOrder;
            return first.subject.compareTo(second.subject);
          });
    return List.unmodifiable(result);
  }
}
