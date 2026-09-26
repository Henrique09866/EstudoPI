import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/study_cycle_subject.dart';
import '../models/study_revision.dart';
import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../services/study_plan_progress.dart';
import '../services/study_revision_planner.dart';
import '../services/study_revision_reminder_scheduler.dart';
import '../services/study_session_storage.dart';
import '../services/study_session_storage_service.dart';
import '../services/study_session_summary.dart';
import '../services/study_time_analytics.dart';
import '../services/study_timer_alarm_scheduler.dart';
import '../services/study_timer_controller.dart';
import '../services/weekly_study_plan_service.dart';
import '../widgets/study_time_chart.dart';
import 'study_cycle_history_page.dart';
import 'study_plan_page.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({
    super.key,
    this.storage,
    this.timerController,
    this.timerAlarms,
    this.timerStatusNotifier,
    this.revisionReminders,
    this.autoStartPomodoro = false,
    this.settings,
    this.subjects = const [],
  });

  final StudySessionStorage? storage;
  final StudyTimerController? timerController;
  final StudyTimerAlarmScheduler? timerAlarms;
  final StudyTimerStatusNotifier? timerStatusNotifier;
  final StudyRevisionReminderScheduler? revisionReminders;
  final bool autoStartPomodoro;
  final AppSettings? settings;
  final List<String> subjects;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  static const _minimumSavedDuration = Duration(minutes: 1);
  static const _goalOptions = [30, 60, 90, 120];
  static const _generalPlan = 'Geral';
  static const _customPlan = 'Outro objetivo';
  static const _defaultStudyPlans = [
    _generalPlan,
    'ENEM',
    'FUVEST',
    'UNICAMP',
    'ITA',
    'IME',
    'AFA',
    'EsPCEx',
    'ESA',
    'EFOMM',
    'EEAR',
    'EPCAR',
    'Colégio Naval',
    'Concurso público',
    'Polícia Militar',
    'Polícia Civil',
    'Corpo de Bombeiros',
    'PRF',
    'PF',
    'Receita Federal',
    'Tribunais',
  ];

  late final StudySessionStorage _storage;
  late final StudyTimerController _timer;
  late final TextEditingController _subjectController;
  late final TextEditingController _quickSubjectController;
  late final TextEditingController _notesController;
  final _studyPlanFieldKey = GlobalKey<FormFieldState<String>>();
  final _planProgressService = const StudyPlanProgressService();
  final _weeklyPlanService = const WeeklyStudyPlanService();
  final _revisionPlanner = const StudyRevisionPlanner();
  Timer? _uiTimer;
  int? _lastTimerNotificationMinute;
  List<StudySession> _sessions = const [];
  List<StudyRevision> _revisions = const [];
  List<StudyWeeklyGoal> _weeklyGoals = const [];
  List<StudyCycleSubject> _cycleSubjects = const [];
  List<StudyCycleCheckIn> _cycleCheckIns = const [];
  List<String> _quickSubjects = const [];
  int _dailyGoalMinutes = StudySessionStorageService.defaultDailyGoalMinutes;
  String? _activeSubject;
  String? _activeStudyPlan;
  String? _activeNotes;
  var _selectedStudyPlan = _generalPlan;
  var _chartPeriod = StudyChartPeriod.today;
  var _chartType = StudyChartType.pie;
  String? _chartStudyPlan;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? StudySessionStorageService.instance();
    final settings = widget.settings;
    _timer =
        widget.timerController ??
        StudyTimerController(
          pomodoroDuration: Duration(
            minutes: settings?.pomodoroFocusMinutes ?? 25,
          ),
          breakDuration: Duration(
            minutes: settings?.pomodoroShortBreakMinutes ?? 5,
          ),
          longBreakDuration: Duration(
            minutes: settings?.pomodoroLongBreakMinutes ?? 15,
          ),
          autoStartBreak: settings?.pomodoroAutoStartBreak ?? false,
        );
    _subjectController = TextEditingController();
    _quickSubjectController = TextEditingController();
    _notesController = TextEditingController();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _loadStudyData();
    if (widget.autoStartPomodoro) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startOrResume());
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _subjectController.dispose();
    _quickSubjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStudyData() async {
    try {
      final results = await Future.wait<Object?>([
        _storage.getSessions(),
        _storage.getDailyGoalMinutes(),
        _storage.getWeeklyGoals(),
        _storage.getRevisions(),
        _storage.getCycleSubjects(),
        _storage.getCycleCheckIns(),
        _storage.getQuickSubjects(),
        _storage.getActiveStudyTimer(),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<StudySession>;
        _dailyGoalMinutes = results[1] as int;
        _weeklyGoals = results[2] as List<StudyWeeklyGoal>;
        _revisions = results[3] as List<StudyRevision>;
        _cycleSubjects = results[4] as List<StudyCycleSubject>;
        _cycleCheckIns = results[5] as List<StudyCycleCheckIn>;
        _quickSubjects = results[6] as List<String>;
        final activeTimer = results[7] as ActiveStudyTimer?;
        if (activeTimer != null) {
          _timer.restore(activeTimer.timer);
          _activeSubject = activeTimer.subject;
          _activeStudyPlan = activeTimer.studyPlan;
          _activeNotes = activeTimer.notes;
          _subjectController.text = activeTimer.subject ?? '';
          _quickSubjectController.text = activeTimer.subject ?? '';
          _notesController.text = activeTimer.notes ?? '';
        }
        _isLoading = false;
      });
      if (_timer.isRunning) {
        unawaited(_scheduleTimerAlarm());
        unawaited(_updateTimerNotification(force: true));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Não foi possível carregar os dados de estudo.');
    }
  }

  void _onTick() {
    final event = _timer.tick();
    if (!mounted) return;
    setState(() {});
    if (event == StudyTimerEvent.focusCompleted) {
      unawaited(_cancelTimerAlarm());
      final result = _timer.completeFocus();
      unawaited(_saveTimerResult(result, automatic: true));
      if (_timer.isRunning) {
        setState(() {});
        unawaited(_persistActiveTimer());
        unawaited(_scheduleTimerAlarm());
        unawaited(_updateTimerNotification(force: true));
      } else {
        unawaited(_clearActiveTimer());
        unawaited(_cancelTimerNotification());
      }
    } else if (event == StudyTimerEvent.breakCompleted) {
      unawaited(_persistActiveTimer());
      unawaited(_cancelTimerNotification());
      _showMessage('Pausa concluída. Pronto para o próximo foco?');
    } else {
      unawaited(_updateTimerNotification());
    }
  }

  void _selectMode(StudySessionType type) {
    if (_timer.hasActiveStudySession) return;
    setState(() => _timer.selectType(type));
    unawaited(_clearActiveTimer());
  }

  void _startOrResume() {
    if (_timer.phase == StudyTimerPhase.focus &&
        !_timer.hasActiveStudySession) {
      _activeSubject = _normalizedSubject;
      _activeStudyPlan = _selectedStudyPlan == _generalPlan
          ? null
          : _selectedStudyPlan;
      _activeNotes = _normalizedNotes;
    }
    setState(_timer.startOrResume);
    unawaited(_persistActiveTimer());
    unawaited(_scheduleTimerAlarm());
    unawaited(_updateTimerNotification(force: true));
  }

  void _startQuickTimer() {
    final subject = _quickSubjectController.text.trim();
    if (subject.isNotEmpty) unawaited(_saveQuickSubject(subject));
    if (!_timer.hasActiveStudySession && !_timer.isRunning) {
      setState(() {
        _timer.selectType(StudySessionType.freeTimer);
        _selectedStudyPlan = _generalPlan;
        _subjectController.text = subject;
        _notesController.clear();
      });
    }
    _startOrResume();
  }

  Future<void> _saveQuickSubject(String subject) async {
    final normalized = subject.trim();
    if (normalized.isEmpty) return;
    try {
      await _storage.saveQuickSubject(normalized);
      if (!mounted) return;
      setState(() {
        _quickSubjects =
            {
              ..._quickSubjects.where(
                (current) => current.toLowerCase() != normalized.toLowerCase(),
              ),
              normalized,
            }.toList()..sort(
              (first, second) =>
                  first.toLowerCase().compareTo(second.toLowerCase()),
            );
      });
    } catch (_) {
      // O cronômetro continua funcionando mesmo sem salvar o atalho.
    }
  }

  void _pause() {
    setState(_timer.pause);
    unawaited(_persistActiveTimer());
    unawaited(_cancelTimerAlarm());
    unawaited(_cancelTimerNotification());
  }

  void _skipBreak() {
    setState(_timer.skipBreak);
    unawaited(_persistActiveTimer());
    unawaited(_cancelTimerAlarm());
    unawaited(_cancelTimerNotification());
  }

  Future<void> _finishStudy() async {
    if (!_timer.hasActiveStudySession) return;
    await _cancelTimerAlarm();
    await _cancelTimerNotification();
    await _saveTimerResult(_timer.finishStudy());
    await _clearActiveTimer();
  }

  Future<void> _scheduleTimerAlarm() async {
    final alarms = widget.timerAlarms;
    final scheduledAt = _timer.alarmAt;
    if (alarms == null || scheduledAt == null) return;
    try {
      await alarms.scheduleStudyTimerAlarm(
        scheduledAt: scheduledAt,
        kind: _timer.phase == StudyTimerPhase.focus
            ? StudyTimerAlarmKind.focusCompleted
            : StudyTimerAlarmKind.breakCompleted,
        subject: [
          _activeSubject,
          _activeStudyPlan,
        ].whereType<String>().join(' · '),
        sound: widget.settings?.pomodoroSoundEnabled ?? true,
        vibration: widget.settings?.pomodoroVibrationEnabled ?? true,
      );
    } catch (_) {
      // O cronômetro continua funcionando mesmo se o sistema bloquear o
      // alarme. O usuário ainda verá o aviso ao voltar para o aplicativo.
      if (mounted) {
        _showMessage('Não foi possível programar o alarme do Pomodoro.');
      }
    }
  }

  Future<void> _cancelTimerAlarm() async {
    try {
      await widget.timerAlarms?.cancelStudyTimerAlarm();
    } catch (_) {
      // Não há ação adicional necessária: o cronômetro local segue correto.
    }
  }

  Future<void> _persistActiveTimer() async {
    if (!_timer.hasActiveStudySession && !_timer.isRunning) {
      await _clearActiveTimer();
      return;
    }
    try {
      await _storage.saveActiveStudyTimer(
        ActiveStudyTimer(
          timer: _timer.snapshot,
          subject: _activeSubject,
          studyPlan: _activeStudyPlan,
          notes: _activeNotes,
        ),
      );
    } catch (_) {
      // O cronômetro continua utilizável mesmo se o armazenamento falhar.
    }
  }

  Future<void> _clearActiveTimer() async {
    try {
      await _storage.clearActiveStudyTimer();
    } catch (_) {
      // Não interrompe a sessão atual se uma limpeza antiga falhar.
    }
  }

  Future<void> _updateTimerNotification({bool force = false}) async {
    if (!_timer.isRunning) return;
    final elapsedMinutes = _timer.elapsed.inMinutes;
    if (!force && elapsedMinutes == _lastTimerNotificationMinute) return;
    _lastTimerNotificationMinute = elapsedMinutes;
    try {
      await widget.timerStatusNotifier?.showStudyTimerStatus(
        elapsed: _timer.elapsed,
        isPomodoro: _timer.type == StudySessionType.pomodoro,
        isBreak: _timer.phase == StudyTimerPhase.breakTime,
        remaining: _timer.type == StudySessionType.pomodoro
            ? _timer.displayedDuration
            : null,
        subject: _activeSubject,
      );
    } catch (_) {
      // Notificações são complementares: a contagem não pode depender delas.
    }
  }

  Future<void> _cancelTimerNotification() async {
    _lastTimerNotificationMinute = null;
    try {
      await widget.timerStatusNotifier?.cancelStudyTimerStatus();
    } catch (_) {
      // Não há ação adicional necessária caso o sistema bloqueie o aviso.
    }
  }

  Future<void> _saveTimerResult(
    StudyTimerResult result, {
    bool automatic = false,
  }) async {
    final subject = _activeSubject;
    final studyPlan = _activeStudyPlan;
    final notes = _activeNotes;
    _activeSubject = null;
    _activeStudyPlan = null;
    _activeNotes = null;
    if (result.duration < _minimumSavedDuration) {
      if (mounted) {
        setState(() {});
        _showMessage('Sessões com menos de 1 minuto não são salvas.');
      }
      return;
    }

    final session = StudySession(
      id: 'study-${result.endedAt.microsecondsSinceEpoch}',
      subject: subject,
      studyPlan: studyPlan,
      notes: notes,
      startedAt: result.startedAt,
      endedAt: result.endedAt,
      duration: result.duration,
      type: result.type,
    );
    try {
      await _storage.saveSession(session);
      final plannedRevisions = _revisionPlanner.revisionsFor(session);
      var revisionsSaved = true;
      try {
        await Future.wait(
          plannedRevisions.map((revision) => _storage.saveRevision(revision)),
        );
      } catch (_) {
        revisionsSaved = false;
      }
      if (revisionsSaved) {
        final reminders = widget.revisionReminders;
        if (reminders != null) {
          try {
            await Future.wait(
              plannedRevisions.map(reminders.scheduleStudyRevisionReminder),
            );
          } catch (_) {
            // As revisões foram salvas e continuam visíveis mesmo se o
            // sistema impedir o lembrete local.
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _sessions = [..._sessions, session];
        if (revisionsSaved) {
          _revisions = [
            ..._revisions.where(
              (current) => !plannedRevisions.any(
                (revision) => revision.id == current.id,
              ),
            ),
            ...plannedRevisions,
          ];
        }
      });
      final subjectLabel = subject == null ? '' : ' em $subject';
      final planLabel = studyPlan == null ? '' : ' para $studyPlan';
      final revisionsLabel = plannedRevisions.isEmpty
          ? ''
          : revisionsSaved
          ? ' Revisões para 1, 7 e 30 dias foram adicionadas.'
          : ' Não foi possível adicionar as revisões automáticas.';
      final nextStep = automatic ? ' Hora da pausa.' : '';
      _showMessage(
        'Sessão concluída: ${_formatMinutes(session.duration)} estudados$subjectLabel$planLabel.$revisionsLabel$nextStep',
      );
    } catch (_) {
      _showMessage('Não foi possível salvar a sessão de estudo.');
    }
  }

  Future<void> _changeDailyGoal() async {
    final customController = TextEditingController(text: '$_dailyGoalMinutes');
    final newGoal = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meta diária'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goalOptions
                  .map(
                    (minutes) => ChoiceChip(
                      label: Text('$minutes min'),
                      selected: customController.text == '$minutes',
                      onSelected: (_) => Navigator.pop(context, minutes),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: customController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Outro valor em minutos',
                suffixText: 'min',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              int.tryParse(customController.text.trim()),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    customController.dispose();
    if (newGoal == null || newGoal <= 0) return;

    try {
      await _storage.saveDailyGoalMinutes(newGoal);
      if (!mounted) return;
      setState(() => _dailyGoalMinutes = newGoal);
      _showMessage('Meta diária atualizada para $newGoal min.');
    } catch (_) {
      _showMessage('Não foi possível atualizar a meta diária.');
    }
  }

  Future<void> _confirmDelete(StudySession session) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Excluir sessão?'),
        content: Text('Remover ${_formatMinutes(session.duration)} estudados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    try {
      await _storage.deleteSession(session.id);
      if (!mounted) return;
      setState(
        () => _sessions = _sessions
            .where((item) => item.id != session.id)
            .toList(),
      );
      _showMessage('Sessão excluída.');
    } catch (_) {
      _showMessage('Não foi possível excluir a sessão.');
    }
  }

  Future<void> _completeRevision(StudyRevision revision) async {
    final completedRevision = revision.copyWith(completedAt: DateTime.now());
    try {
      await _storage.saveRevision(completedRevision);
      await widget.revisionReminders?.cancelStudyRevisionReminder(
        completedRevision.id,
      );
      if (!mounted) return;
      setState(
        () => _revisions = [
          for (final current in _revisions)
            if (current.id == completedRevision.id)
              completedRevision
            else
              current,
        ],
      );
      _showMessage('${revision.subject} marcada como revisada.');
    } catch (_) {
      _showMessage('Não foi possível concluir a revisão.');
    }
  }

  Future<void> _addCycleSubject() async {
    final subjectName = await showDialog<String>(
      context: context,
      builder: (context) => const _CycleSubjectDialog(),
    );
    if (subjectName == null || subjectName.isEmpty || !mounted) return;
    if (_cycleSubjects.any(
      (subject) => subject.name.toLowerCase() == subjectName.toLowerCase(),
    )) {
      _showMessage('Essa matéria já está no seu ciclo.');
      return;
    }
    final subject = StudyCycleSubject(
      id: 'cycle-subject-${DateTime.now().microsecondsSinceEpoch}',
      name: subjectName,
      colorIndex: _cycleSubjects.length,
    );
    try {
      await _storage.saveCycleSubject(subject);
      if (!mounted) return;
      setState(
        () =>
            _cycleSubjects = [..._cycleSubjects, subject]
              ..sort((first, second) => first.name.compareTo(second.name)),
      );
    } catch (_) {
      _showMessage('Não foi possível adicionar a matéria ao ciclo.');
    }
  }

  Future<void> _deleteCycleSubject(StudyCycleSubject subject) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover matéria do ciclo'),
        content: Text(
          'Remover ${subject.name}? As marcações dessa matéria também sairão do histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    try {
      await _storage.deleteCycleSubject(subject.id);
      if (!mounted) return;
      setState(() {
        _cycleSubjects = _cycleSubjects
            .where((current) => current.id != subject.id)
            .toList();
        _cycleCheckIns = _cycleCheckIns
            .where((checkIn) => checkIn.subjectId != subject.id)
            .toList();
      });
    } catch (_) {
      _showMessage('Não foi possível remover a matéria do ciclo.');
    }
  }

  Future<void> _toggleCycleCheckIn(
    StudyCycleSubject subject,
    DateTime day,
  ) async {
    final today = StudyCycleCalendar.dateOnly(DateTime.now());
    if (StudyCycleCalendar.dateOnly(day).isAfter(today)) return;
    final checkIn = StudyCycleCheckIn(subjectId: subject.id, day: day);
    final existing = _cycleCheckIns.where(
      (current) => current.id == checkIn.id,
    );
    try {
      if (existing.isEmpty) {
        await _storage.saveCycleCheckIn(checkIn);
        if (!mounted) return;
        setState(() => _cycleCheckIns = [..._cycleCheckIns, checkIn]);
      } else {
        await _storage.deleteCycleCheckIn(checkIn.id);
        if (!mounted) return;
        setState(
          () => _cycleCheckIns = _cycleCheckIns
              .where((current) => current.id != checkIn.id)
              .toList(),
        );
      }
    } catch (_) {
      _showMessage('Não foi possível atualizar a marcação do ciclo.');
    }
  }

  Future<void> _openCycleHistory() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (context) => StudyCycleHistoryPage(
        subjects: List.of(_cycleSubjects),
        checkIns: List.of(_cycleCheckIns),
      ),
    ),
  );

  Future<void> _openStudyPlan() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudyPlanPage(
          storage: _storage,
          sessions: List.of(_sessions),
          suggestedPlans: _studyPlanOptions
              .where((plan) => plan != _generalPlan && plan != _customPlan)
              .toList(),
          suggestedSubjects: _subjectSuggestions,
        ),
      ),
    );
    if (!mounted) return;
    try {
      final goals = await _storage.getWeeklyGoals();
      if (mounted) setState(() => _weeklyGoals = goals);
    } catch (_) {
      _showMessage('Não foi possível atualizar o plano de estudos.');
    }
  }

  Future<void> _confirmExit() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sessão em andamento'),
        content: const Text('Deseja sair e encerrar esta sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      await _cancelTimerAlarm();
      await _cancelTimerNotification();
      await _saveTimerResult(_timer.finishStudy());
      await _clearActiveTimer();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  String? get _normalizedSubject {
    final subject = _subjectController.text.trim();
    return subject.isEmpty ? null : subject;
  }

  String? get _normalizedNotes {
    final notes = _notesController.text.trim();
    return notes.isEmpty ? null : notes;
  }

  List<String> get _studyPlanOptions {
    final savedPlans = StudyTimeAnalytics.availableStudyPlans(_sessions);
    final options = <String>{..._defaultStudyPlans, ...savedPlans};
    if (_selectedStudyPlan != _generalPlan) options.add(_selectedStudyPlan);
    return [...options, _customPlan];
  }

  List<String> get _subjectSuggestions {
    final subjects = <String>{
      ...widget.subjects.map((subject) => subject.trim()),
      ..._quickSubjects,
      ..._sessions
          .map((session) => session.subject?.trim())
          .whereType<String>(),
    }..removeWhere((subject) => subject.isEmpty);
    final result = subjects.toList()..sort();
    return result;
  }

  Future<void> _selectStudyPlan(String plan) async {
    if (plan != _customPlan) {
      setState(() => _selectedStudyPlan = plan);
      return;
    }

    final controller = TextEditingController();
    final customPlan = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo objetivo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Objetivo de estudo',
            hintText: 'Ex.: FUVEST',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Usar objetivo'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (customPlan == null || customPlan.isEmpty || !mounted) return;
    setState(() => _selectedStudyPlan = customPlan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _studyPlanFieldKey.currentState?.didChange(customPlan);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _scrollableTab(List<Widget> children) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final todaySessions = StudySessionSummary.sessionsForDay(
      _sessions,
      DateTime.now(),
    )..sort((first, second) => second.startedAt.compareTo(first.startedAt));
    final totalToday = StudySessionSummary.totalForDay(
      _sessions,
      DateTime.now(),
    );
    final bySubject = StudySessionSummary.totalBySubjectForDay(
      _sessions,
      DateTime.now(),
    ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final availableStudyPlans = StudyTimeAnalytics.availableStudyPlans(
      _sessions,
    );
    final selectedChartPlan = availableStudyPlans.contains(_chartStudyPlan)
        ? _chartStudyPlan
        : null;
    final chartSubjects = StudyTimeAnalytics.bySubject(
      sessions: _sessions,
      period: _chartPeriod,
      studyPlan: selectedChartPlan,
    );
    final weeklyProgress = _planProgressService.calculate(
      sessions: _sessions,
      goals: _weeklyGoals,
    );
    final todayRecommendations = _weeklyPlanService.recommendationsForToday(
      sessions: _sessions,
      goals: _weeklyGoals,
    );
    final pendingRevisions = _revisionPlanner.pendingForDay(
      _revisions,
      DateTime.now(),
    );
    final nextDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day + 1,
    );
    final upcomingRevisions =
        _revisions
            .where(
              (revision) =>
                  !revision.isCompleted &&
                  !revision.scheduledFor.isBefore(nextDay),
            )
            .toList()
          ..sort(
            (first, second) =>
                first.scheduledFor.compareTo(second.scheduledFor),
          );
    final cycleWeekDays = StudyCycleCalendar.weekDays(DateTime.now());
    final progress = _dailyGoalMinutes == 0
        ? 0.0
        : (totalToday.inSeconds /
                  Duration(minutes: _dailyGoalMinutes).inSeconds)
              .clamp(0.0, 1.0);
    final isBreak = _timer.phase == StudyTimerPhase.breakTime;
    final isPomodoro = _timer.type == StudySessionType.pomodoro;
    final hasActive = _timer.hasActiveStudySession;

    return DefaultTabController(
      length: 5,
      child: PopScope(
        canPop: !hasActive,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && hasActive) _confirmExit();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Área de estudos'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.timer_outlined), text: 'Sessão'),
                Tab(icon: Icon(Icons.insights_outlined), text: 'Painel'),
                Tab(icon: Icon(Icons.play_circle_outline), text: 'Rápido'),
                Tab(icon: Icon(Icons.repeat_rounded), text: 'Revisões'),
                Tab(icon: Icon(Icons.grid_view_rounded), text: 'Ciclo'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _scrollableTab([
                      Text(
                        'Escolha o foco e comece sua próxima sessão.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _StudySetup(
                        studyPlanFieldKey: _studyPlanFieldKey,
                        selectedStudyPlan: _selectedStudyPlan,
                        studyPlanOptions: _studyPlanOptions,
                        timerType: _timer.type,
                        enabled: !hasActive,
                        onStudyPlanChanged: _selectStudyPlan,
                        onTimerTypeChanged: _selectMode,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('study-subject-field'),
                        controller: _subjectController,
                        enabled: !hasActive,
                        decoration: const InputDecoration(
                          labelText: 'Matéria (opcional)',
                          hintText: 'Ex.: Física',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('study-notes-field'),
                        controller: _notesController,
                        enabled: !hasActive,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Notas da sessão (opcional)',
                          hintText: 'Ex.: rever exercícios 4 e 5',
                          prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        ),
                      ),
                      if (_subjectSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _subjectSuggestions
                              .map(
                                (subject) => ActionChip(
                                  label: Text(subject),
                                  onPressed: hasActive
                                      ? null
                                      : () => setState(
                                          () =>
                                              _subjectController.text = subject,
                                        ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _TimerPanel(
                        duration: _timer.displayedDuration,
                        alarmAt: _timer.alarmAt,
                        isPomodoro: isPomodoro,
                        isBreak: isBreak,
                        isLongBreak: _timer.isLongBreak,
                        isRunning: _timer.isRunning,
                        hasActiveStudy: hasActive,
                        onStartOrResume: _startOrResume,
                        onPause: _pause,
                        onFinish: _finishStudy,
                        onSkipBreak: _skipBreak,
                      ),
                      if (todayRecommendations.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _TodayStudyPlanCard(
                          recommendations: todayRecommendations,
                          onOpenPlan: _openStudyPlan,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _DailyGoalCard(
                        total: totalToday,
                        goalMinutes: _dailyGoalMinutes,
                        progress: progress,
                        onEdit: _changeDailyGoal,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sessões de hoje',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (todaySessions.isEmpty)
                        const _EmptyHistory()
                      else
                        for (final session in todaySessions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SessionTile(
                              session: session,
                              onDelete: () => _confirmDelete(session),
                            ),
                          ),
                    ]),
                    _scrollableTab([
                      Text(
                        'Acompanhe suas metas e distribua melhor o tempo de estudo.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _WeeklyPlanSummary(
                        progress: weeklyProgress,
                        onOpenPlan: _openStudyPlan,
                      ),
                      const SizedBox(height: 20),
                      _StudyDashboard(
                        period: _chartPeriod,
                        chartType: _chartType,
                        selectedPlan: selectedChartPlan,
                        studyPlans: availableStudyPlans,
                        subjects: chartSubjects,
                        onPeriodChanged: (period) {
                          setState(() => _chartPeriod = period);
                        },
                        onChartTypeChanged: (type) {
                          setState(() => _chartType = type);
                        },
                        onStudyPlanChanged: (plan) {
                          setState(() => _chartStudyPlan = plan);
                        },
                      ),
                      if (bySubject.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _SubjectSummary(entries: bySubject),
                      ],
                    ]),
                    _scrollableTab([
                      _QuickTimerCard(
                        controller: _quickSubjectController,
                        suggestions: _subjectSuggestions,
                        activeSubject: _activeSubject,
                        isRunning: _timer.isRunning,
                        hasActiveStudy: hasActive,
                        duration: _timer.elapsed,
                        onStartOrResume: _startQuickTimer,
                        onPause: _pause,
                        onFinish: _finishStudy,
                        onSelectSubject: (subject) => setState(
                          () => _quickSubjectController.text = subject,
                        ),
                      ),
                    ]),
                    _scrollableTab([
                      Text(
                        'Revisar no intervalo certo ajuda a transformar estudo em memória.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _RevisionTodayCard(
                        revisions: pendingRevisions,
                        onComplete: _completeRevision,
                      ),
                      const SizedBox(height: 20),
                      _UpcomingRevisionsCard(revisions: upcomingRevisions),
                      const SizedBox(height: 20),
                      const _RevisionRhythmCard(),
                    ]),
                    _scrollableTab([
                      Text(
                        'Monte seu ritmo livremente. Marque apenas o que você estudou — sem ordem obrigatória.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _StudyCycleCard(
                        subjects: _cycleSubjects,
                        checkIns: _cycleCheckIns,
                        weekDays: cycleWeekDays,
                        onAddSubject: _addCycleSubject,
                        onDeleteSubject: _deleteCycleSubject,
                        onToggleCheckIn: _toggleCycleCheckIn,
                        onOpenHistory: _openCycleHistory,
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Entrada enxuta para começar uma matéria sem configurar objetivo ou notas.
/// Se existir uma sessão pausada, o Play a continua em vez de criar outra.
class _QuickTimerCard extends StatelessWidget {
  const _QuickTimerCard({
    required this.controller,
    required this.suggestions,
    required this.activeSubject,
    required this.isRunning,
    required this.hasActiveStudy,
    required this.duration,
    required this.onStartOrResume,
    required this.onPause,
    required this.onFinish,
    required this.onSelectSubject,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String? activeSubject;
  final bool isRunning;
  final bool hasActiveStudy;
  final Duration duration;
  final VoidCallback onStartOrResume;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final ValueChanged<String> onSelectSubject;

  @override
  Widget build(BuildContext context) {
    final subject = activeSubject?.trim();
    final hasNamedActiveStudy = subject != null && subject.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cronômetro rápido',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveStudy
                  ? hasNamedActiveStudy
                        ? 'Você está estudando $subject. Use Play para continuar de onde parou.'
                        : 'Há uma sessão em andamento. Use Play para continuar de onde parou.'
                  : 'Digite a matéria, por exemplo Física, e aperte Play. Ela ficará salva abaixo como atalho e o cronômetro continua mesmo ao fechar o app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const ValueKey('quick-study-subject-field'),
              controller: controller,
              enabled: !hasActiveStudy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Matéria',
                hintText: 'Ex.: Física',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              onSubmitted: (_) => onStartOrResume(),
            ),
            if (!hasActiveStudy && suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: suggestions
                    .map(
                      (item) => ActionChip(
                        label: Text(item),
                        onPressed: () => onSelectSubject(item),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (hasActiveStudy) ...[
              const SizedBox(height: 20),
              Text(
                _formatTimer(duration, withHours: true),
                key: const ValueKey('quick-study-timer-display'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (isRunning)
              FilledButton.icon(
                key: const ValueKey('quick-study-pause-button'),
                onPressed: onPause,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pausar'),
              )
            else
              FilledButton.icon(
                key: const ValueKey('quick-study-play-button'),
                onPressed: onStartOrResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(hasActiveStudy ? 'Continuar' : 'Play'),
              ),
            if (hasActiveStudy) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Finalizar sessão'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active_outlined, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '🔔 Aviso com o tempo estudado ativo durante a sessão',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleSubjectDialog extends StatefulWidget {
  const _CycleSubjectDialog();

  @override
  State<_CycleSubjectDialog> createState() => _CycleSubjectDialogState();
}

class _CycleSubjectDialogState extends State<_CycleSubjectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nova matéria no ciclo'),
    content: TextField(
      key: const ValueKey('cycle-subject-name-field'),
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Matéria',
        hintText: 'Ex.: Matemática',
        prefixIcon: Icon(Icons.menu_book_outlined),
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Adicionar')),
    ],
  );
}

class _StudyCycleCard extends StatelessWidget {
  const _StudyCycleCard({
    required this.subjects,
    required this.checkIns,
    required this.weekDays,
    required this.onAddSubject,
    required this.onDeleteSubject,
    required this.onToggleCheckIn,
    required this.onOpenHistory,
  });

  final List<StudyCycleSubject> subjects;
  final List<StudyCycleCheckIn> checkIns;
  final List<DateTime> weekDays;
  final Future<void> Function() onAddSubject;
  final Future<void> Function(StudyCycleSubject) onDeleteSubject;
  final Future<void> Function(StudyCycleSubject, DateTime) onToggleCheckIn;
  final Future<void> Function() onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final today = StudyCycleCalendar.dateOnly(DateTime.now());
    final weekStart = weekDays.first;
    final weekEnd = weekDays.last;
    final thisWeek = checkIns
        .where(
          (checkIn) =>
              !checkIn.day.isBefore(weekStart) && !checkIn.day.isAfter(weekEnd),
        )
        .toList();
    final checkInIds = {for (final checkIn in thisWeek) checkIn.id};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Seu ciclo da semana',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('add-cycle-subject-button'),
                  onPressed: onAddSubject,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Matéria'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatCycleWeek(weekStart)} · ${thisWeek.length} ${thisWeek.length == 1 ? 'marcação' : 'marcações'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Não existe ordem fixa: escolha a matéria que faz sentido para você. Na próxima segunda, a grade começa nova e seu histórico permanece.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (subjects.isEmpty)
              _CycleEmptyState(onAddSubject: onAddSubject)
            else
              _CycleWeekGrid(
                subjects: subjects,
                weekDays: weekDays,
                checkInIds: checkInIds,
                today: today,
                onDeleteSubject: onDeleteSubject,
                onToggleCheckIn: onToggleCheckIn,
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: const ValueKey('open-cycle-history-button'),
              onPressed: onOpenHistory,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Ver histórico do ano'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleEmptyState extends StatelessWidget {
  const _CycleEmptyState({required this.onAddSubject});

  final Future<void> Function() onAddSubject;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.grid_view_rounded),
          const SizedBox(height: 10),
          Text(
            'Crie seu primeiro ciclo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Adicione Matemática, Inglês, Português ou qualquer matéria que você queira estudar.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddSubject,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar matéria'),
          ),
        ],
      ),
    ),
  );
}

class _CycleWeekGrid extends StatelessWidget {
  const _CycleWeekGrid({
    required this.subjects,
    required this.weekDays,
    required this.checkInIds,
    required this.today,
    required this.onDeleteSubject,
    required this.onToggleCheckIn,
  });

  static const _subjectColumnWidth = 152.0;
  static const _dayColumnWidth = 48.0;
  static const _weekDayLabels = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  final List<StudyCycleSubject> subjects;
  final List<DateTime> weekDays;
  final Set<String> checkInIds;
  final DateTime today;
  final Future<void> Function(StudyCycleSubject) onDeleteSubject;
  final Future<void> Function(StudyCycleSubject, DateTime) onToggleCheckIn;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SizedBox(
      width: _subjectColumnWidth + (_dayColumnWidth * weekDays.length),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: _subjectColumnWidth,
                child: Text('Matéria'),
              ),
              for (var index = 0; index < weekDays.length; index++)
                SizedBox(
                  width: _dayColumnWidth,
                  child: _CycleDayHeader(
                    label: _weekDayLabels[index],
                    day: weekDays[index],
                    isToday:
                        StudyCycleCalendar.dayKey(weekDays[index]) ==
                        StudyCycleCalendar.dayKey(today),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final subject in subjects) ...[
            Row(
              children: [
                SizedBox(
                  width: _subjectColumnWidth,
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _cycleSubjectColor(
                            context,
                            subject.colorIndex,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 10, height: 10),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subject.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover ${subject.name}',
                        onPressed: () => onDeleteSubject(subject),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                for (final day in weekDays)
                  SizedBox(
                    width: _dayColumnWidth,
                    child: Center(
                      child: _CycleDayCell(
                        subject: subject,
                        day: day,
                        isMarked: checkInIds.contains(
                          StudyCycleCheckIn.idFor(
                            subjectId: subject.id,
                            day: day,
                          ),
                        ),
                        isFuture: day.isAfter(today),
                        onTap: () => onToggleCheckIn(subject, day),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}

class _CycleDayHeader extends StatelessWidget {
  const _CycleDayHeader({
    required this.label,
    required this.day,
    required this.isToday,
  });

  final String label;
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 2),
      Text(
        '${day.day}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: isToday ? FontWeight.w800 : null,
          color: isToday ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    ],
  );
}

class _CycleDayCell extends StatelessWidget {
  const _CycleDayCell({
    required this.subject,
    required this.day,
    required this.isMarked,
    required this.isFuture,
    required this.onTap,
  });

  final StudyCycleSubject subject;
  final DateTime day;
  final bool isMarked;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subjectColor = _cycleSubjectColor(context, subject.colorIndex);
    final date =
        '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
    final label =
        '$date, ${subject.name}: '
        '${isMarked
            ? 'estudada'
            : isFuture
            ? 'dia futuro'
            : 'não marcada'}';
    return Semantics(
      label: label,
      button: true,
      enabled: !isFuture,
      child: InkWell(
        key: ValueKey(
          'cycle-check-in-${subject.id}-${StudyCycleCalendar.dayKey(day)}',
        ),
        onTap: isFuture ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isMarked
                ? subjectColor
                : isFuture
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : subjectColor.withValues(alpha: .14),
            border: Border.all(
              color: isMarked
                  ? subjectColor
                  : subjectColor.withValues(alpha: isFuture ? .14 : .48),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isMarked
              ? Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                )
              : null,
        ),
      ),
    );
  }
}

Color _cycleSubjectColor(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  final colors = [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    scheme.error,
  ];
  return colors[index % colors.length];
}

String _formatCycleWeek(DateTime weekStart) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  final weekEnd = weekStart.add(const Duration(days: 6));
  if (weekStart.month == weekEnd.month) {
    return '${weekStart.day}–${weekEnd.day} ${months[weekStart.month - 1]}';
  }
  return '${weekStart.day} ${months[weekStart.month - 1]}–'
      '${weekEnd.day} ${months[weekEnd.month - 1]}';
}

class _RevisionTodayCard extends StatelessWidget {
  const _RevisionTodayCard({required this.revisions, required this.onComplete});

  final List<StudyRevision> revisions;
  final ValueChanged<StudyRevision> onComplete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Revisões de hoje',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (revisions.isEmpty)
            Text(
              'Tudo em dia. As próximas revisões aparecerão aqui no momento certo.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              'Reserve alguns minutos para reforçar o que já estudou.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final revision in revisions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(revision.subject),
                          Text(
                            '${revision.suggestedMinutes} min${revision.studyPlan == null ? '' : ' · ${revision.studyPlan}'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: ValueKey('complete-revision-${revision.id}'),
                      onPressed: () => onComplete(revision),
                      child: const Text('Revisada'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class _UpcomingRevisionsCard extends StatelessWidget {
  const _UpcomingRevisionsCard({required this.revisions});

  final List<StudyRevision> revisions;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Próximas revisões',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (revisions.isEmpty)
            Text(
              'As revisões futuras aparecerão aqui quando você concluir uma sessão com matéria.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final revision in revisions.take(4))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        revision.studyPlan == null
                            ? revision.subject
                            : '${revision.subject} · ${revision.studyPlan}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_formatShortDate(revision.scheduledFor)),
                  ],
                ),
              ),
          if (revisions.length > 4) ...[
            const SizedBox(height: 10),
            Text(
              '+ ${revisions.length - 4} revisão(ões) agendada(s)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _RevisionRhythmCard extends StatelessWidget {
  const _RevisionRhythmCard();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ritmo de revisão',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _RevisionStep(day: '1 dia', label: 'Relembre'),
              _RevisionStep(day: '7 dias', label: 'Consolide'),
              _RevisionStep(day: '30 dias', label: 'Fortaleça'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RevisionStep extends StatelessWidget {
  const _RevisionStep({required this.day, required this.label});

  final String day;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day, style: Theme.of(context).textTheme.labelLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _WeeklyPlanSummary extends StatelessWidget {
  const _WeeklyPlanSummary({required this.progress, required this.onOpenPlan});

  final List<WeeklyGoalProgress> progress;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plano da semana',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                key: const ValueKey('open-study-plan-button'),
                onPressed: onOpenPlan,
                child: Text(progress.isEmpty ? 'Criar plano' : 'Gerenciar'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (progress.isEmpty)
            Text(
              'Defina metas por matéria e acompanhe o que falta para a semana.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final item in progress.take(3)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.goal.studyPlan == null
                          ? item.goal.subject
                          : '${item.goal.subject} · ${item.goal.studyPlan}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_formatMinutes(item.studied)} / ${_formatMinutes(item.target)}',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: item.completion, minHeight: 7),
            ],
          if (progress.length > 3) ...[
            const SizedBox(height: 12),
            Text(
              '+ ${progress.length - 3} meta(s) no plano',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _StudyDashboard extends StatelessWidget {
  const _StudyDashboard({
    required this.period,
    required this.chartType,
    required this.selectedPlan,
    required this.studyPlans,
    required this.subjects,
    required this.onPeriodChanged,
    required this.onChartTypeChanged,
    required this.onStudyPlanChanged,
  });

  final StudyChartPeriod period;
  final StudyChartType chartType;
  final String? selectedPlan;
  final List<String> studyPlans;
  final List<StudySubjectTotal> subjects;
  final ValueChanged<StudyChartPeriod> onPeriodChanged;
  final ValueChanged<StudyChartType> onChartTypeChanged;
  final ValueChanged<String?> onStudyPlanChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tempo por matéria',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Veja onde suas horas de foco foram investidas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: const ValueKey('study-chart-plan-filter'),
            initialValue: selectedPlan,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Objetivo no gráfico',
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Todos os objetivos',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...studyPlans.map(
                (plan) => DropdownMenuItem<String?>(
                  value: plan,
                  child: Text(plan, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: onStudyPlanChanged,
          ),
          const SizedBox(height: 16),
          Text('Período', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StudyChartPeriod.values
                .map(
                  (option) => ChoiceChip(
                    key: ValueKey('study-chart-period-${option.name}'),
                    label: Text(option.label),
                    selected: period == option,
                    onSelected: (_) => onPeriodChanged(option),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Tipo de gráfico',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StudyChartType.values
                .map(
                  (option) => ChoiceChip(
                    key: ValueKey('study-chart-type-${option.name}'),
                    avatar: Icon(option.icon, size: 18),
                    label: Text(option.label),
                    selected: chartType == option,
                    onSelected: (_) => onChartTypeChanged(option),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          StudyTimeChart(subjects: subjects, type: chartType),
        ],
      ),
    ),
  );
}

class _StudySetup extends StatelessWidget {
  const _StudySetup({
    required this.studyPlanFieldKey,
    required this.selectedStudyPlan,
    required this.studyPlanOptions,
    required this.timerType,
    required this.enabled,
    required this.onStudyPlanChanged,
    required this.onTimerTypeChanged,
  });

  final GlobalKey<FormFieldState<String>> studyPlanFieldKey;
  final String selectedStudyPlan;
  final List<String> studyPlanOptions;
  final StudySessionType timerType;
  final bool enabled;
  final ValueChanged<String> onStudyPlanChanged;
  final ValueChanged<StudySessionType> onTimerTypeChanged;

  @override
  Widget build(BuildContext context) {
    final planField = KeyedSubtree(
      key: const ValueKey('study-plan-field'),
      child: DropdownButtonFormField<String>(
        key: studyPlanFieldKey,
        initialValue: selectedStudyPlan,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Objetivo de estudo',
          prefixIcon: Icon(Icons.flag_outlined),
        ),
        items: studyPlanOptions
            .map(
              (plan) => DropdownMenuItem(
                value: plan,
                child: Text(plan, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: enabled
            ? (plan) {
                if (plan != null) onStudyPlanChanged(plan);
              }
            : null,
      ),
    );
    final modeSelector = _ModeSelector(
      value: timerType,
      enabled: enabled,
      onChanged: onTimerTypeChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [planField, const SizedBox(height: 16), modeSelector],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: planField),
            const SizedBox(width: 16),
            Expanded(child: modeSelector),
          ],
        );
      },
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final StudySessionType value;
  final bool enabled;
  final ValueChanged<StudySessionType> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<StudySessionType>(
    segments: const [
      ButtonSegment(
        value: StudySessionType.pomodoro,
        icon: Icon(Icons.timer_outlined),
        label: Text('Pomodoro'),
      ),
      ButtonSegment(
        value: StudySessionType.freeTimer,
        icon: Icon(Icons.timer_rounded),
        label: Text('Cronômetro'),
      ),
    ],
    selected: {value},
    onSelectionChanged: enabled ? (values) => onChanged(values.first) : null,
  );
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({
    required this.duration,
    required this.alarmAt,
    required this.isPomodoro,
    required this.isBreak,
    required this.isLongBreak,
    required this.isRunning,
    required this.hasActiveStudy,
    required this.onStartOrResume,
    required this.onPause,
    required this.onFinish,
    required this.onSkipBreak,
  });

  final Duration duration;
  final DateTime? alarmAt;
  final bool isPomodoro;
  final bool isBreak;
  final bool isLongBreak;
  final bool isRunning;
  final bool hasActiveStudy;
  final VoidCallback onStartOrResume;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onSkipBreak;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final phaseLabel = isBreak
        ? isLongBreak
              ? 'PAUSA LONGA'
              : 'PAUSA'
        : 'FOCO';
    final phaseIcon = isBreak
        ? Icons.coffee_outlined
        : Icons.center_focus_strong;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            if (isPomodoro)
              Chip(avatar: Icon(phaseIcon, size: 18), label: Text(phaseLabel))
            else
              const Chip(
                avatar: Icon(Icons.timer_outlined, size: 18),
                label: Text('CRONÔMETRO LIVRE'),
              ),
            const SizedBox(height: 18),
            Text(
              _formatTimer(duration, withHours: !isPomodoro),
              key: const ValueKey('study-timer-display'),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
                letterSpacing: 1.5,
              ),
            ),
            if (alarmAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Alarme programado para ${_formatTime(alarmAt!)}',
                key: const ValueKey('study-timer-alarm-time'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (isRunning) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '🔔 Aviso com o tempo em andamento ativo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (isRunning)
              FilledButton.icon(
                key: const ValueKey('study-pause-button'),
                onPressed: onPause,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pausar'),
              )
            else
              FilledButton.icon(
                key: const ValueKey('study-start-button'),
                onPressed: onStartOrResume,
                icon: Icon(
                  hasActiveStudy
                      ? Icons.play_arrow_rounded
                      : Icons.play_circle_outline,
                ),
                label: Text(
                  isBreak
                      ? 'Iniciar pausa'
                      : hasActiveStudy
                      ? 'Continuar'
                      : 'Iniciar',
                ),
              ),
            if (isBreak) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                key: const ValueKey('study-skip-break-button'),
                onPressed: onSkipBreak,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Pular pausa'),
              ),
            ] else if (hasActiveStudy) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                key: const ValueKey('study-finish-button'),
                onPressed: onFinish,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Finalizar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayStudyPlanCard extends StatelessWidget {
  const _TodayStudyPlanCard({
    required this.recommendations,
    required this.onOpenPlan,
  });

  final List<DailyStudyRecommendation> recommendations;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final preview = recommendations.take(3).toList();
    final totalMinutes = recommendations.fold<int>(
      0,
      (total, item) => total + item.recommendedMinutes,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Plano de hoje',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenPlan,
                  child: const Text('Ver plano'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reserve cerca de $totalMinutes min para manter suas metas da semana em dia.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final recommendation in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          recommendation.subject,
                          if (recommendation.studyPlan != null)
                            recommendation.studyPlan!,
                        ].join(' · '),
                      ),
                    ),
                    Text(
                      '${recommendation.recommendedMinutes} min',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            if (recommendations.length > preview.length)
              Text(
                '+ ${recommendations.length - preview.length} matéria(s) no plano',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({
    required this.total,
    required this.goalMinutes,
    required this.progress,
    required this.onEdit,
  });

  final Duration total;
  final int goalMinutes;
  final double progress;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Meta de hoje',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                key: const ValueKey('edit-daily-goal-button'),
                tooltip: 'Alterar meta diária',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${_formatMinutes(total)} / $goalMinutes min'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 8),
          const SizedBox(height: 8),
          Text('${(progress * 100).round()}% concluído'),
        ],
      ),
    ),
  );
}

class _SubjectSummary extends StatelessWidget {
  const _SubjectSummary({required this.entries});

  final List<MapEntry<String, Duration>> entries;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Por matéria',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(_formatMinutes(entry.value)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onDelete});

  final StudySession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        session.type == StudySessionType.pomodoro
            ? Icons.timer_outlined
            : Icons.timer_rounded,
      ),
      title: Text(session.subject ?? 'Sem matéria'),
      subtitle: Text(
        '${_formatMinutes(session.duration)} · ${_formatTime(session.startedAt)}–${_formatTime(session.endedAt)}'
        '${session.notes == null ? '' : '\n${session.notes}'}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Excluir sessão',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.school_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhuma sessão registrada hoje. Comece quando estiver pronto.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatTimer(Duration duration, {required bool withHours}) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return withHours
      ? '$hours:$minutes:$seconds'
      : '${duration.inMinutes.toString().padLeft(2, '0')}:$seconds';
}

String _formatMinutes(Duration duration) {
  final minutes = duration.inMinutes;
  return '$minutes min';
}

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _formatShortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
