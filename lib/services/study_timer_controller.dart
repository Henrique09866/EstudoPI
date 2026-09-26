import '../models/study_session.dart';

enum StudyTimerPhase { focus, breakTime }

enum StudyTimerEvent { none, focusCompleted, breakCompleted }

class StudyTimerController {
  StudyTimerController({
    DateTime Function()? now,
    this.pomodoroDuration = const Duration(minutes: 25),
    this.breakDuration = const Duration(minutes: 5),
    this.longBreakDuration = const Duration(minutes: 15),
    this.autoStartBreak = false,
    this.focusSessionsBeforeLongBreak = 4,
  }) : assert(focusSessionsBeforeLongBreak > 0),
       _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration pomodoroDuration;
  final Duration breakDuration;
  final Duration longBreakDuration;
  final bool autoStartBreak;
  final int focusSessionsBeforeLongBreak;

  StudySessionType type = StudySessionType.pomodoro;
  StudyTimerPhase phase = StudyTimerPhase.focus;
  bool isRunning = false;
  DateTime? _sessionStartedAt;
  DateTime? _runningSince;
  Duration _elapsedBeforePause = Duration.zero;
  var _completedFocusSessions = 0;
  var _isLongBreak = false;

  bool get hasActiveStudySession => _sessionStartedAt != null;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  bool get isLongBreak => _isLongBreak;

  /// Uma cópia serializável do cronômetro atual. Ela permite que uma sessão
  /// continue de onde parou mesmo depois de trocar de tela ou fechar o app.
  StudyTimerSnapshot get snapshot => StudyTimerSnapshot(
    type: type,
    phase: phase,
    isRunning: isRunning,
    sessionStartedAt: _sessionStartedAt,
    runningSince: _runningSince,
    elapsedBeforePause: _elapsedBeforePause,
    completedFocusSessions: _completedFocusSessions,
    isLongBreak: _isLongBreak,
  );

  /// Restaura uma sessão salva. Não restaura configurações do Pomodoro, pois
  /// elas continuam vindo das preferências atuais da pessoa.
  void restore(StudyTimerSnapshot value) {
    type = value.type;
    phase = value.phase;
    isRunning = value.isRunning;
    _sessionStartedAt = value.sessionStartedAt;
    _runningSince = value.runningSince;
    _elapsedBeforePause = value.elapsedBeforePause;
    _completedFocusSessions = value.completedFocusSessions;
    _isLongBreak = value.isLongBreak;
  }

  Duration get elapsed => _elapsedBeforePause + _runningElapsed;

  Duration get _runningElapsed => isRunning && _runningSince != null
      ? _now().difference(_runningSince!)
      : Duration.zero;

  Duration get displayedDuration {
    if (type == StudySessionType.freeTimer) return elapsed;
    final limit = phase == StudyTimerPhase.focus
        ? pomodoroDuration
        : _currentBreakDuration;
    final remaining = limit - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Horário previsto para o alarme da etapa atual do Pomodoro.
  ///
  /// O cronômetro livre não possui um fim definido, portanto não programa
  /// alarme nesse modo.
  DateTime? get alarmAt {
    if (!isRunning || type != StudySessionType.pomodoro) return null;
    return _now().add(displayedDuration);
  }

  void selectType(StudySessionType newType) {
    if (hasActiveStudySession || isRunning) return;
    type = newType;
    phase = StudyTimerPhase.focus;
    _elapsedBeforePause = Duration.zero;
  }

  void startOrResume() {
    if (isRunning) return;
    if (phase == StudyTimerPhase.focus && _sessionStartedAt == null) {
      _sessionStartedAt = _now();
    }
    _runningSince = _now();
    isRunning = true;
  }

  void pause() {
    if (!isRunning) return;
    _elapsedBeforePause = elapsed;
    _runningSince = null;
    isRunning = false;
  }

  StudyTimerEvent tick() {
    if (!isRunning || type == StudySessionType.freeTimer) {
      return StudyTimerEvent.none;
    }
    final limit = phase == StudyTimerPhase.focus
        ? pomodoroDuration
        : _currentBreakDuration;
    if (elapsed < limit) return StudyTimerEvent.none;

    _elapsedBeforePause = limit;
    _runningSince = null;
    isRunning = false;
    if (phase == StudyTimerPhase.focus) {
      _completedFocusSessions++;
      _isLongBreak =
          _completedFocusSessions % focusSessionsBeforeLongBreak == 0;
      phase = StudyTimerPhase.breakTime;
      return StudyTimerEvent.focusCompleted;
    }
    phase = StudyTimerPhase.focus;
    _elapsedBeforePause = Duration.zero;
    _isLongBreak = false;
    return StudyTimerEvent.breakCompleted;
  }

  StudyTimerResult finishStudy() {
    pause();
    final result = StudyTimerResult(
      startedAt: _sessionStartedAt ?? _now(),
      endedAt: _now(),
      duration: elapsed,
      type: type,
    );
    _resetFocus();
    return result;
  }

  StudyTimerResult completeFocus() {
    final result = StudyTimerResult(
      startedAt: _sessionStartedAt ?? _now(),
      endedAt: _now(),
      duration: pomodoroDuration,
      type: StudySessionType.pomodoro,
    );
    _sessionStartedAt = null;
    _elapsedBeforePause = Duration.zero;
    if (autoStartBreak) {
      _runningSince = _now();
      isRunning = true;
    }
    return result;
  }

  void skipBreak() {
    if (phase != StudyTimerPhase.breakTime) return;
    isRunning = false;
    _runningSince = null;
    _elapsedBeforePause = Duration.zero;
    phase = StudyTimerPhase.focus;
    _isLongBreak = false;
  }

  void discardActiveStudy() => _resetFocus();

  void _resetFocus() {
    isRunning = false;
    _runningSince = null;
    _elapsedBeforePause = Duration.zero;
    _sessionStartedAt = null;
    phase = StudyTimerPhase.focus;
    _isLongBreak = false;
  }

  Duration get _currentBreakDuration =>
      _isLongBreak ? longBreakDuration : breakDuration;
}

class StudyTimerResult {
  const StudyTimerResult({
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.type,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final StudySessionType type;
}

/// Estado persistido do cronômetro. Os valores de data são ISO-8601 para que
/// possam ser guardados tanto no Hive quanto em futuros backups.
class StudyTimerSnapshot {
  const StudyTimerSnapshot({
    required this.type,
    required this.phase,
    required this.isRunning,
    required this.sessionStartedAt,
    required this.runningSince,
    required this.elapsedBeforePause,
    required this.completedFocusSessions,
    required this.isLongBreak,
  });

  final StudySessionType type;
  final StudyTimerPhase phase;
  final bool isRunning;
  final DateTime? sessionStartedAt;
  final DateTime? runningSince;
  final Duration elapsedBeforePause;
  final int completedFocusSessions;
  final bool isLongBreak;

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'phase': phase.name,
    'isRunning': isRunning,
    'sessionStartedAt': sessionStartedAt?.toIso8601String(),
    'runningSince': runningSince?.toIso8601String(),
    'elapsedMilliseconds': elapsedBeforePause.inMilliseconds,
    'completedFocusSessions': completedFocusSessions,
    'isLongBreak': isLongBreak,
  };

  factory StudyTimerSnapshot.fromMap(Map<String, dynamic> map) {
    final type = _enumByName(StudySessionType.values, map['type']);
    final phase = _enumByName(StudyTimerPhase.values, map['phase']);
    final isRunning = map['isRunning'];
    final elapsedMilliseconds = map['elapsedMilliseconds'];
    final completedFocusSessions = map['completedFocusSessions'];
    final isLongBreak = map['isLongBreak'];
    if (type == null ||
        phase == null ||
        isRunning is! bool ||
        elapsedMilliseconds is! num ||
        elapsedMilliseconds.isNegative ||
        completedFocusSessions is! num ||
        completedFocusSessions.isNegative ||
        isLongBreak is! bool) {
      throw const FormatException('Cronômetro salvo inválido.');
    }
    return StudyTimerSnapshot(
      type: type,
      phase: phase,
      isRunning: isRunning,
      sessionStartedAt: _dateFromMap(map['sessionStartedAt']),
      runningSince: _dateFromMap(map['runningSince']),
      elapsedBeforePause: Duration(milliseconds: elapsedMilliseconds.toInt()),
      completedFocusSessions: completedFocusSessions.toInt(),
      isLongBreak: isLongBreak,
    );
  }

  static T? _enumByName<T extends Enum>(Iterable<T> values, Object? value) {
    if (value is! String) return null;
    for (final item in values) {
      if (item.name == value) return item;
    }
    return null;
  }

  static DateTime? _dateFromMap(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Data inválida.');
    return DateTime.parse(value);
  }
}

/// Cronômetro em andamento junto dos dados que devem acompanhar a sessão ao
/// ser salva (matéria, objetivo e anotações).
class ActiveStudyTimer {
  const ActiveStudyTimer({
    required this.timer,
    this.subject,
    this.studyPlan,
    this.notes,
  });

  final StudyTimerSnapshot timer;
  final String? subject;
  final String? studyPlan;
  final String? notes;

  Map<String, dynamic> toMap() => {
    ...timer.toMap(),
    'subject': subject,
    'studyPlan': studyPlan,
    'notes': notes,
  };

  factory ActiveStudyTimer.fromMap(Map<String, dynamic> map) =>
      ActiveStudyTimer(
        timer: StudyTimerSnapshot.fromMap(map),
        subject: _optionalText(map['subject']),
        studyPlan: _optionalText(map['studyPlan']),
        notes: _optionalText(map['notes']),
      );

  static String? _optionalText(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Texto inválido.');
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
