import 'package:hive_flutter/hive_flutter.dart';

import '../models/study_session.dart';
import 'study_session_storage.dart';

class StudySessionStorageService implements StudySessionStorage {
  StudySessionStorageService(this._sessionsBox, this._settingsBox);

  static const sessionsBoxName = 'study_sessions';
  static const settingsBoxName = 'study_settings';
  static const _dailyGoalKey = 'daily_goal_minutes';
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
}
