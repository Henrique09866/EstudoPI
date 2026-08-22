import 'package:flutter/material.dart';

import '../models/study_session.dart';
import '../models/task.dart';
import '../services/progress_summary.dart';
import '../services/study_session_storage.dart';
import '../services/study_session_storage_service.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    required this.tasks,
    this.storage,
    this.initialSessions,
  });

  final List<Task> tasks;
  final StudySessionStorage? storage;
  final List<StudySession>? initialSessions;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _summaryService = const ProgressSummaryService();
  late List<StudySession> _sessions;
  var _period = ProgressPeriod.today;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sessions = List.of(widget.initialSessions ?? const []);
    if (widget.initialSessions != null) {
      _isLoading = false;
      return;
    }
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final storage = widget.storage ?? StudySessionStorageService.instance();
      final sessions = await storage.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar o progresso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summaryService.calculate(
      tasks: widget.tasks,
      sessions: _sessions,
      period: _period,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Meu progresso')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Acompanhe seu ritmo de estudo e tarefas.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 20),
                        SegmentedButton<ProgressPeriod>(
                          key: const ValueKey('progress-period-selector'),
                          segments: const [
                            ButtonSegment(
                              value: ProgressPeriod.today,
                              label: Text('Hoje'),
                            ),
                            ButtonSegment(
                              value: ProgressPeriod.last7Days,
                              label: Text('7 dias'),
                            ),
                            ButtonSegment(
                              value: ProgressPeriod.last30Days,
                              label: Text('30 dias'),
                            ),
                          ],
                          selected: {_period},
                          onSelectionChanged: (periods) {
                            setState(() => _period = periods.first);
                          },
                        ),
                        const SizedBox(height: 20),
                        _ProgressMetrics(summary: summary),
                        const SizedBox(height: 20),
                        _CompletionCard(summary: summary),
                        if (summary.hasData) ...[
                          if (summary.studyDays > 0) ...[
                            const SizedBox(height: 20),
                            _StudyDaysCard(
                              days: summary.studyDays,
                              period: _period,
                            ),
                          ],
                          if (summary.subjects.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _SubjectRanking(subjects: summary.subjects),
                          ],
                        ] else ...[
                          const SizedBox(height: 20),
                          const _ProgressEmptyState(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProgressMetrics extends StatelessWidget {
  const _ProgressMetrics({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = [
      _MetricData(
        label: 'Tempo estudado',
        value: _formatDuration(summary.studyDuration),
        icon: Icons.timer_outlined,
        color: colorScheme.primary,
      ),
      _MetricData(
        label: 'Concluídas',
        value: '${summary.completedTasks}',
        icon: Icons.task_alt_rounded,
        color: colorScheme.tertiary,
      ),
      _MetricData(
        label: 'Pendentes',
        value: '${summary.pendingTasks}',
        icon: Icons.pending_actions_outlined,
        color: colorScheme.secondary,
      ),
      _MetricData(
        label: 'Atrasadas',
        value: '${summary.overdueTasks}',
        icon: Icons.error_outline_rounded,
        color: colorScheme.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (metric) => SizedBox(width: width, child: _MetricCard(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final _MetricData metric;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: metric.color),
          const SizedBox(height: 14),
          Text(
            metric.value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            metric.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final percentage = (summary.completionRate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taxa de conclusão',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage% das tarefas relevantes no período',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: summary.completionRate.clamp(0, 1),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyDaysCard extends StatelessWidget {
  const _StudyDaysCard({required this.days, required this.period});

  final int days;
  final ProgressPeriod period;

  @override
  Widget build(BuildContext context) {
    final periodText = switch (period) {
      ProgressPeriod.today => 'hoje',
      ProgressPeriod.last7Days => 'nos últimos 7 dias',
      ProgressPeriod.last30Days => 'nos últimos 30 dias',
    };
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: const Text('Dias com estudo'),
        subtitle: Text('$days $periodText'),
        trailing: Text(
          '$days',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SubjectRanking extends StatelessWidget {
  const _SubjectRanking({required this.subjects});

  final List<ProgressSubjectEntry> subjects;

  @override
  Widget build(BuildContext context) {
    final largestDuration = subjects.first.duration;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tempo por matéria',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            for (final subject in subjects) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_formatDuration(subject.duration)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: largestDuration == Duration.zero
                    ? 0
                    : subject.duration.inSeconds / largestDuration.inSeconds,
                minHeight: 7,
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressEmptyState extends StatelessWidget {
  const _ProgressEmptyState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ainda não há dados suficientes. Conclua tarefas e registre sessões de estudo para acompanhar seu progresso.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

String formatProgressDuration(Duration duration) => _formatDuration(duration);

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}min';
}
