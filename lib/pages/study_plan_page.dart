import 'package:flutter/material.dart';

import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../services/study_plan_progress.dart';
import '../services/study_session_storage.dart';

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({
    super.key,
    required this.storage,
    required this.sessions,
    this.suggestedPlans = const [],
    this.suggestedSubjects = const [],
  });

  final StudySessionStorage storage;
  final List<StudySession> sessions;
  final List<String> suggestedPlans;
  final List<String> suggestedSubjects;

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  static const _targetOptions = [60, 120, 180, 300];

  final _planController = TextEditingController();
  final _subjectController = TextEditingController();
  final _minutesController = TextEditingController(text: '120');
  final _progressService = const StudyPlanProgressService();
  List<StudyWeeklyGoal> _goals = const [];
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _planController.dispose();
    _subjectController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await widget.storage.getWeeklyGoals();
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Não foi possível carregar o plano de estudos.');
    }
  }

  Future<void> _saveGoal() async {
    final subject = _subjectController.text.trim();
    final minutes = int.tryParse(_minutesController.text.trim());
    if (subject.isEmpty) {
      _showMessage('Informe a matéria da meta.');
      return;
    }
    if (minutes == null || minutes <= 0) {
      _showMessage('Informe uma meta semanal válida em minutos.');
      return;
    }
    final plan = _planController.text.trim();
    final goal = StudyWeeklyGoal(
      studyPlan: plan.isEmpty ? null : plan,
      subject: subject,
      targetMinutes: minutes,
    );
    try {
      await widget.storage.saveWeeklyGoal(goal);
      if (!mounted) return;
      setState(() {
        _goals = [..._goals.where((current) => current.id != goal.id), goal]
          ..sort((first, second) {
            final planOrder = (first.studyPlan ?? '').compareTo(
              second.studyPlan ?? '',
            );
            return planOrder != 0
                ? planOrder
                : first.subject.compareTo(second.subject);
          });
        _subjectController.clear();
      });
      _showMessage('Meta semanal salva.');
    } catch (_) {
      _showMessage('Não foi possível salvar a meta semanal.');
    }
  }

  Future<void> _deleteGoal(StudyWeeklyGoal goal) async {
    try {
      await widget.storage.deleteWeeklyGoal(goal.id);
      if (!mounted) return;
      setState(
        () =>
            _goals = _goals.where((current) => current.id != goal.id).toList(),
      );
      _showMessage('Meta removida.');
    } catch (_) {
      _showMessage('Não foi possível remover a meta.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progressService.calculate(
      sessions: widget.sessions,
      goals: _goals,
    );
    final planSuggestions = {...widget.suggestedPlans}
      ..removeWhere((plan) => plan.trim().isEmpty);
    final subjectSuggestions = {...widget.suggestedSubjects}
      ..removeWhere((subject) => subject.trim().isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Plano de estudos')),
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
                          'Defina quanto tempo quer estudar por matéria a cada semana.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Nova meta semanal',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  key: const ValueKey('weekly-goal-plan-field'),
                                  controller: _planController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Objetivo (opcional)',
                                    hintText: 'Ex.: ENEM',
                                    prefixIcon: Icon(Icons.flag_outlined),
                                  ),
                                ),
                                if (planSuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: planSuggestions
                                        .map(
                                          (plan) => ActionChip(
                                            label: Text(plan),
                                            onPressed: () => setState(
                                              () => _planController.text = plan,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextField(
                                  key: const ValueKey(
                                    'weekly-goal-subject-field',
                                  ),
                                  controller: _subjectController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Matéria',
                                    hintText: 'Ex.: Matemática',
                                    prefixIcon: Icon(Icons.menu_book_outlined),
                                  ),
                                ),
                                if (subjectSuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: subjectSuggestions
                                        .map(
                                          (subject) => ActionChip(
                                            label: Text(subject),
                                            onPressed: () => setState(
                                              () => _subjectController.text =
                                                  subject,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextField(
                                  key: const ValueKey(
                                    'weekly-goal-minutes-field',
                                  ),
                                  controller: _minutesController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Meta por semana',
                                    suffixText: 'minutos',
                                    prefixIcon: Icon(Icons.timer_outlined),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _targetOptions
                                      .map(
                                        (minutes) => ChoiceChip(
                                          label: Text(
                                            _formatDuration(
                                              Duration(minutes: minutes),
                                            ),
                                          ),
                                          selected:
                                              _minutesController.text ==
                                              '$minutes',
                                          onSelected: (_) => setState(
                                            () => _minutesController.text =
                                                '$minutes',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  key: const ValueKey(
                                    'save-weekly-goal-button',
                                  ),
                                  onPressed: _saveGoal,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Salvar meta'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Metas desta semana',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        if (progress.isEmpty)
                          const _EmptyGoals()
                        else
                          for (final item in progress)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _GoalProgressCard(
                                progress: item,
                                onDelete: () => _deleteGoal(item.goal),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({required this.progress, required this.onDelete});

  final WeeklyGoalProgress progress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.goal.subject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (progress.goal.studyPlan != null)
                      Text(
                        progress.goal.studyPlan!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remover meta',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatDuration(progress.studied)} de ${_formatDuration(progress.target)}',
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress.completion, minHeight: 8),
          const SizedBox(height: 7),
          Text(
            progress.completion == 1
                ? 'Meta concluída nesta semana.'
                : 'Faltam ${_formatDuration(progress.remaining)} para concluir.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.track_changes_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Crie uma meta para comparar suas horas estudadas com o planejado.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}min';
}
