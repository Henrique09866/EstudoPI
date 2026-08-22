import 'dart:async';

import 'package:flutter/material.dart';

import '../models/study_session.dart';
import '../services/study_session_storage.dart';
import '../services/study_session_storage_service.dart';
import '../services/study_session_summary.dart';
import '../services/study_timer_controller.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({
    super.key,
    this.storage,
    this.timerController,
    this.subjects = const [],
  });

  final StudySessionStorage? storage;
  final StudyTimerController? timerController;
  final List<String> subjects;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  static const _minimumSavedDuration = Duration(minutes: 1);
  static const _goalOptions = [30, 60, 90, 120];

  late final StudySessionStorage _storage;
  late final StudyTimerController _timer;
  late final TextEditingController _subjectController;
  Timer? _uiTimer;
  List<StudySession> _sessions = const [];
  int _dailyGoalMinutes = StudySessionStorageService.defaultDailyGoalMinutes;
  String? _activeSubject;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? StudySessionStorageService.instance();
    _timer = widget.timerController ?? StudyTimerController();
    _subjectController = TextEditingController();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _loadStudyData();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadStudyData() async {
    try {
      final results = await Future.wait<Object>([
        _storage.getSessions(),
        _storage.getDailyGoalMinutes(),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<StudySession>;
        _dailyGoalMinutes = results[1] as int;
        _isLoading = false;
      });
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
      _saveTimerResult(_timer.completeFocus(), automatic: true);
    } else if (event == StudyTimerEvent.breakCompleted) {
      _showMessage('Pausa concluída. Pronto para o próximo foco?');
    }
  }

  void _selectMode(StudySessionType type) {
    if (_timer.hasActiveStudySession) return;
    setState(() => _timer.selectType(type));
  }

  void _startOrResume() {
    if (_timer.phase == StudyTimerPhase.focus &&
        !_timer.hasActiveStudySession) {
      _activeSubject = _normalizedSubject;
    }
    setState(_timer.startOrResume);
  }

  void _pause() => setState(_timer.pause);

  Future<void> _finishStudy() async {
    if (!_timer.hasActiveStudySession) return;
    await _saveTimerResult(_timer.finishStudy());
  }

  Future<void> _saveTimerResult(
    StudyTimerResult result, {
    bool automatic = false,
  }) async {
    final subject = _activeSubject;
    _activeSubject = null;
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
      startedAt: result.startedAt,
      endedAt: result.endedAt,
      duration: result.duration,
      type: result.type,
    );
    try {
      await _storage.saveSession(session);
      if (!mounted) return;
      setState(() => _sessions = [..._sessions, session]);
      final subjectLabel = subject == null ? '' : ' em $subject';
      final nextStep = automatic ? ' Hora da pausa.' : '';
      _showMessage(
        'Sessão concluída: ${_formatMinutes(session.duration)} estudados$subjectLabel.$nextStep',
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
      await _saveTimerResult(_timer.finishStudy());
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  String? get _normalizedSubject {
    final subject = _subjectController.text.trim();
    return subject.isEmpty ? null : subject;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
    final progress = _dailyGoalMinutes == 0
        ? 0.0
        : (totalToday.inSeconds /
                  Duration(minutes: _dailyGoalMinutes).inSeconds)
              .clamp(0.0, 1.0);
    final isBreak = _timer.phase == StudyTimerPhase.breakTime;
    final isPomodoro = _timer.type == StudySessionType.pomodoro;
    final hasActive = _timer.hasActiveStudySession;

    return PopScope(
      canPop: !hasActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasActive) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Modo Estudo')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Concentre-se em uma sessão por vez.',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 20),
                          _ModeSelector(
                            value: _timer.type,
                            enabled: !hasActive,
                            onChanged: _selectMode,
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
                          if (widget.subjects.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: widget.subjects
                                  .map(
                                    (subject) => ActionChip(
                                      label: Text(subject),
                                      onPressed: hasActive
                                          ? null
                                          : () => setState(
                                              () => _subjectController.text =
                                                  subject,
                                            ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _TimerPanel(
                            duration: _timer.displayedDuration,
                            isPomodoro: isPomodoro,
                            isBreak: isBreak,
                            isRunning: _timer.isRunning,
                            hasActiveStudy: hasActive,
                            onStartOrResume: _startOrResume,
                            onPause: _pause,
                            onFinish: _finishStudy,
                            onSkipBreak: () => setState(_timer.skipBreak),
                          ),
                          const SizedBox(height: 20),
                          _DailyGoalCard(
                            total: totalToday,
                            goalMinutes: _dailyGoalMinutes,
                            progress: progress,
                            onEdit: _changeDailyGoal,
                          ),
                          if (bySubject.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _SubjectSummary(entries: bySubject),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            'Sessões de hoje',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
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
    required this.isPomodoro,
    required this.isBreak,
    required this.isRunning,
    required this.hasActiveStudy,
    required this.onStartOrResume,
    required this.onPause,
    required this.onFinish,
    required this.onSkipBreak,
  });

  final Duration duration;
  final bool isPomodoro;
  final bool isBreak;
  final bool isRunning;
  final bool hasActiveStudy;
  final VoidCallback onStartOrResume;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onSkipBreak;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final phaseLabel = isBreak ? 'PAUSA' : 'FOCO';
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
        '${_formatMinutes(session.duration)} · ${_formatTime(session.startedAt)}–${_formatTime(session.endedAt)}',
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
