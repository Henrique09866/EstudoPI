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
