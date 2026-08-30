import 'package:flutter/material.dart';

import '../models/study_cycle_subject.dart';

class StudyCycleHistoryPage extends StatelessWidget {
  const StudyCycleHistoryPage({
    super.key,
    required this.subjects,
    required this.checkIns,
    this.now,
  });

  final List<StudyCycleSubject> subjects;
  final List<StudyCycleCheckIn> checkIns;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final reference = now ?? DateTime.now();
    final year = reference.year;
    final subjectNames = {
      for (final subject in subjects) subject.id: subject.name,
    };
    final checkInsByDay = <String, List<StudyCycleCheckIn>>{};
    for (final checkIn in checkIns.where((item) => item.day.year == year)) {
      final dayCheckIns = checkInsByDay.putIfAbsent(
        StudyCycleCalendar.dayKey(checkIn.day),
        () => [],
      );
      dayCheckIns.add(checkIn);
    }
    final activeDays = checkInsByDay.length;
    final totalCheckIns = checkInsByDay.values.fold<int>(
      0,
      (total, items) => total + items.length,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico do ciclo')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$year em quadradinhos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cada quadrado representa um dia. Quanto mais forte a cor, mais matérias você marcou.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _HistoryStats(
                    activeDays: activeDays,
                    totalCheckIns: totalCheckIns,
                  ),
                  const SizedBox(height: 20),
                  _YearHeatmap(
                    year: year,
                    checkInsByDay: checkInsByDay,
                    subjectNames: subjectNames,
                  ),
                  const SizedBox(height: 16),
                  const _HeatmapLegend(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryStats extends StatelessWidget {
  const _HistoryStats({required this.activeDays, required this.totalCheckIns});

  final int activeDays;
  final int totalCheckIns;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _HistoryMetric(
              value: '$activeDays',
              label: activeDays == 1 ? 'dia marcado' : 'dias marcados',
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: _HistoryMetric(
              value: '$totalCheckIns',
              label: totalCheckIns == 1
                  ? 'matéria registrada'
                  : 'matérias registradas',
            ),
          ),
        ],
      ),
    ),
  );
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _YearHeatmap extends StatelessWidget {
  const _YearHeatmap({
    required this.year,
    required this.checkInsByDay,
    required this.subjectNames,
  });

  final int year;
  final Map<String, List<StudyCycleCheckIn>> checkInsByDay;
  final Map<String, String> subjectNames;

  @override
  Widget build(BuildContext context) {
    final firstWeek = StudyCycleCalendar.weekStart(DateTime(year));
    final lastDay = DateTime(year, 12, 31);
    final weeks = <List<DateTime>>[];
    for (
      var week = firstWeek;
      !week.isAfter(lastDay);
      week = week.add(const Duration(days: 7))
    ) {
      weeks.add(List.generate(7, (index) => week.add(Duration(days: index))));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Presença no estudo',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 30),
                  for (final week in weeks)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Column(
                        children: [
                          for (final day in week)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: _HeatmapDay(
                                day: day,
                                isInYear: day.year == year,
                                checkIns:
                                    checkInsByDay[StudyCycleCalendar.dayKey(
                                      day,
                                    )] ??
                                    const [],
                                subjectNames: subjectNames,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapDay extends StatelessWidget {
  const _HeatmapDay({
    required this.day,
    required this.isInYear,
    required this.checkIns,
    required this.subjectNames,
  });

  final DateTime day;
  final bool isInYear;
  final List<StudyCycleCheckIn> checkIns;
  final Map<String, String> subjectNames;

  @override
  Widget build(BuildContext context) {
    final count = checkIns.length;
    final label = _dayDescription(day, count, subjectNames, checkIns);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _heatmapColor(context, count, isInYear),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const SizedBox(width: 12, height: 12),
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'Menos',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      for (final count in [0, 1, 2, 3])
        DecoratedBox(
          decoration: BoxDecoration(
            color: _heatmapColor(context, count, true),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const SizedBox(width: 12, height: 12),
        ),
      Text(
        'Mais',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

Color _heatmapColor(BuildContext context, int count, bool isInYear) {
  if (!isInYear) return Colors.transparent;
  final scheme = Theme.of(context).colorScheme;
  if (count == 0) return scheme.surfaceContainerHighest;
  return Color.lerp(
    scheme.primary.withValues(alpha: .35),
    scheme.primary,
    ((count - 1) / 2).clamp(0.0, 1.0),
  )!;
}

String _dayDescription(
  DateTime day,
  int count,
  Map<String, String> subjectNames,
  List<StudyCycleCheckIn> checkIns,
) {
  final date =
      '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/'
      '${day.year}';
  if (count == 0) return '$date: nenhuma matéria marcada.';
  final subjects = checkIns
      .map((checkIn) => subjectNames[checkIn.subjectId] ?? 'Matéria removida')
      .join(', ');
  return '$date: $count ${count == 1 ? 'matéria' : 'matérias'} marcada(s): $subjects.';
}
