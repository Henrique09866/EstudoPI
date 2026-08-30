import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/study_time_analytics.dart';

enum StudyChartType { pie, bars }

extension StudyChartTypeLabel on StudyChartType {
  String get label => switch (this) {
    StudyChartType.pie => 'Pizza',
    StudyChartType.bars => 'Barras',
  };

  IconData get icon => switch (this) {
    StudyChartType.pie => Icons.pie_chart_outline_rounded,
    StudyChartType.bars => Icons.bar_chart_rounded,
  };
}

class StudyTimeChart extends StatelessWidget {
  const StudyTimeChart({super.key, required this.subjects, required this.type});

  final List<StudySubjectTotal> subjects;
  final StudyChartType type;

  static const _colors = [
    Color(0xff6750a4),
    Color(0xff006e1c),
    Color(0xff9c4235),
    Color(0xff00658a),
    Color(0xff765b00),
    Color(0xff7d5260),
    Color(0xff38656a),
    Color(0xff575f71),
  ];

  @override
  Widget build(BuildContext context) {
    final total = StudyTimeAnalytics.total(subjects);
    if (subjects.isEmpty || total == Duration.zero) {
      return const _ChartEmptyState();
    }

    return Column(
      children: [
        SizedBox(
          height: 210,
          width: double.infinity,
          child: type == StudyChartType.pie
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 210),
                      painter: _PieChartPainter(
                        subjects: subjects,
                        total: total,
                        colors: _colors,
                        centerColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(total),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'no período',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                )
              : CustomPaint(
                  size: const Size(double.infinity, 210),
                  painter: _BarChartPainter(
                    subjects: subjects,
                    colors: _colors,
                    baselineColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < subjects.length; index++)
          _ChartLegendRow(
            subject: subjects[index],
            color: _colors[index % _colors.length],
            total: total,
          ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({
    required this.subjects,
    required this.total,
    required this.colors,
    required this.centerColor,
  });

  final List<StudySubjectTotal> subjects;
  final Duration total;
  final List<Color> colors;
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height) * .86;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: diameter,
      height: diameter,
    );
    var startAngle = -math.pi / 2;
    for (var index = 0; index < subjects.length; index++) {
      final sweepAngle =
          math.pi * 2 * (subjects[index].duration.inSeconds / total.inSeconds);
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..color = colors[index % colors.length]
          ..style = PaintingStyle.fill,
      );
      startAngle += sweepAngle;
    }
    canvas.drawCircle(
      rect.center,
      diameter * .27,
      Paint()..color = centerColor,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.subjects != subjects ||
      oldDelegate.total != total ||
      oldDelegate.centerColor != centerColor;
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.subjects,
    required this.colors,
    required this.baselineColor,
  });

  final List<StudySubjectTotal> subjects;
  final List<Color> colors;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final largest = subjects.first.duration.inSeconds;
    final baseline = size.height - 8;
    final usableWidth = size.width - 24;
    final gap = subjects.length == 1 ? 0.0 : 10.0;
    final barWidth = math.max(
      8.0,
      (usableWidth - gap * (subjects.length - 1)) / subjects.length,
    );
    final actualWidth = math.min(barWidth, 42.0);
    final totalBarsWidth =
        actualWidth * subjects.length + gap * (subjects.length - 1);
    final start = (size.width - totalBarsWidth) / 2;
    const maxHeight = 174.0;

    canvas.drawLine(
      Offset(12, baseline),
      Offset(size.width - 12, baseline),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 1,
    );

    for (var index = 0; index < subjects.length; index++) {
      final height = largest == 0
          ? 0.0
          : maxHeight * subjects[index].duration.inSeconds / largest;
      final left = start + index * (actualWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, baseline - height, actualWidth, height),
          const Radius.circular(6),
        ),
        Paint()..color = colors[index % colors.length],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.subjects != subjects ||
      oldDelegate.baselineColor != baselineColor;
}

class _ChartLegendRow extends StatelessWidget {
  const _ChartLegendRow({
    required this.subject,
    required this.color,
    required this.total,
  });

  final StudySubjectTotal subject;
  final Color color;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final percentage = total == Duration.zero
        ? 0
        : (subject.duration.inSeconds / total.inSeconds * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 10, height: 10),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subject.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text('${_formatDuration(subject.duration)} · $percentage%'),
        ],
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        const Icon(Icons.pie_chart_outline_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Nenhuma sessão foi registrada neste período. Escolha uma matéria e inicie o Pomodoro para acompanhar as horas.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}min';
}
