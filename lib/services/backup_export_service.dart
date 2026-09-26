import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/mock_exam.dart';
import '../models/study_revision.dart';
import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../models/task.dart';

class BackupExportData {
  const BackupExportData({
    required this.settings,
    required this.tasks,
    required this.sessions,
    required this.weeklyGoals,
    required this.revisions,
    required this.mockExams,
  });

  final AppSettings settings;
  final List<Task> tasks;
  final List<StudySession> sessions;
  final List<StudyWeeklyGoal> weeklyGoals;
  final List<StudyRevision> revisions;
  final List<MockExam> mockExams;

  Map<String, dynamic> toMap(DateTime exportedAt) => {
    'formatVersion': 1,
    'exportedAt': exportedAt.toIso8601String(),
    'settings': settings.toMap(),
    'tasks': tasks.map((task) => task.toMap()).toList(),
    'studySessions': sessions.map((session) => session.toMap()).toList(),
    'weeklyGoals': weeklyGoals.map((goal) => goal.toMap()).toList(),
    'revisions': revisions.map((revision) => revision.toMap()).toList(),
    'mockExams': mockExams.map((exam) => exam.toMap()).toList(),
  };
}

class BackupExportResult {
  const BackupExportResult({
    required this.backupFile,
    required this.csvFile,
    required this.pdfFile,
  });

  final File backupFile;
  final File csvFile;
  final File pdfFile;

  String get directoryPath => backupFile.parent.path;
}

/// Cria cópias locais sem alterar os dados salvos no aplicativo.
class BackupExportService {
  BackupExportService({
    Future<Directory> Function()? documentsDirectory,
    DateTime Function()? now,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _now;

  Future<BackupExportResult> exportAll(BackupExportData data) async {
    final directory = Directory(
      '${(await _documentsDirectory()).path}/backups',
    );
    await directory.create(recursive: true);
    final exportedAt = _now();
    final suffix = _fileSuffix(exportedAt);
    final backupFile = File('${directory.path}/curujao-backup-$suffix.json');
    final csvFile = File('${directory.path}/curujao-estudos-$suffix.csv');
    final pdfFile = File('${directory.path}/curujao-relatorio-$suffix.pdf');

    await backupFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toMap(exportedAt)),
      flush: true,
    );
    await csvFile.writeAsString(_buildCsv(data), flush: true);
    await pdfFile.writeAsBytes(_buildPdf(data, exportedAt), flush: true);
    return BackupExportResult(
      backupFile: backupFile,
      csvFile: csvFile,
      pdfFile: pdfFile,
    );
  }

  static String _buildCsv(BackupExportData data) {
    final rows = <List<String>>[
      [
        'tipo',
        'data',
        'objetivo',
        'matéria/título',
        'tempo_minutos',
        'meta_minutos',
        'questões',
        'acertos',
        'observações',
      ],
      ...data.sessions.map(
        (session) => [
          'sessão',
          session.startedAt.toIso8601String(),
          session.studyPlan ?? '',
          session.subject ?? '',
          '${session.duration.inMinutes}',
          '',
          '',
          '',
          session.notes ?? '',
        ],
      ),
      ...data.weeklyGoals.map(
        (goal) => [
          'meta semanal',
          '',
          goal.studyPlan ?? '',
          goal.subject,
          '',
          '${goal.targetMinutes}',
          '',
          '',
          '',
        ],
      ),
      ...data.mockExams.map(
        (exam) => [
          'simulado',
          exam.takenAt.toIso8601String(),
          exam.studyPlan ?? '',
          exam.title,
          '${exam.duration.inMinutes}',
          '',
          '${exam.totalQuestions}',
          '${exam.correctAnswers}',
          exam.notes ?? '',
        ],
      ),
    ];
    return '${rows.map((row) => row.map(_csvCell).join(';')).join('\n')}\n';
  }

  static String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  static List<int> _buildPdf(BackupExportData data, DateTime exportedAt) {
    final lines = <String>[
      'Relatorio Curujao Estudos',
      'Gerado em ${_dateLabel(exportedAt)}',
      '',
      'Resumo',
      'Sessoes de estudo: ${data.sessions.length}',
      'Metas semanais: ${data.weeklyGoals.length}',
      'Simulados: ${data.mockExams.length}',
      'Tarefas: ${data.tasks.length}',
      '',
      'Metas semanais',
      if (data.weeklyGoals.isEmpty)
        'Nenhuma meta registrada.'
      else
        ...data.weeklyGoals.map(
          (goal) =>
              '${goal.subject} ${_planSuffix(goal.studyPlan)}: ${goal.targetMinutes} min',
        ),
      '',
      'Sessoes de estudo',
      if (data.sessions.isEmpty)
        'Nenhuma sessao registrada.'
      else
        ...data.sessions.map(
          (session) =>
              '${_dateLabel(session.startedAt)} - ${session.subject ?? 'Sem materia'} ${_planSuffix(session.studyPlan)}: ${session.duration.inMinutes} min',
        ),
      '',
      'Simulados',
      if (data.mockExams.isEmpty)
        'Nenhum simulado registrado.'
      else
        ...data.mockExams.map(
          (exam) =>
              '${_dateLabel(exam.takenAt)} - ${exam.title}: ${exam.correctAnswers}/${exam.totalQuestions} acertos',
        ),
    ].map(_pdfSafeText).toList();

    const maxLinesPerPage = 43;
    final pages = <List<String>>[];
    for (var index = 0; index < lines.length; index += maxLinesPerPage) {
      pages.add(
        lines.sublist(index, (index + maxLinesPerPage).clamp(0, lines.length)),
      );
    }
    if (pages.isEmpty) pages.add(const []);

    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [${List.generate(pages.length, (index) => '${4 + index * 2} 0 R').join(' ')}] /Count ${pages.length} >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    for (var index = 0; index < pages.length; index++) {
      final pageObject = 4 + index * 2;
      final contentObject = pageObject + 1;
      final content = _pdfPageContent(pages[index]);
      objects.add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentObject 0 R >>',
      );
      objects.add(
        '<< /Length ${utf8.encode(content).length} >>\nstream\n$content\nendstream',
      );
    }

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (var index = 0; index < objects.length; index++) {
      offsets.add(utf8.encode(buffer.toString()).length);
      buffer.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
    }
    final xrefOffset = utf8.encode(buffer.toString()).length;
    buffer.write('xref\n0 ${objects.length + 1}\n');
    buffer.write('0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF',
    );
    return utf8.encode(buffer.toString());
  }

  static String _pdfPageContent(List<String> lines) {
    final content = StringBuffer('BT\n/F1 11 Tf\n50 800 Td\n15 TL\n');
    for (final line in lines) {
      content.write(
        '(${line.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)')}) Tj\nT*\n',
      );
    }
    return '${content}ET';
  }

  static String _pdfSafeText(String value) {
    final ascii = value
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[ÁÀÃÂÄ]'), 'A')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[ÓÒÕÔÖ]'), 'O')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
    final normalized = ascii
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '?')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized.substring(0, normalized.length.clamp(0, 105));
  }

  static String _fileSuffix(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _planSuffix(String? plan) =>
      plan == null || plan.isEmpty ? '' : '($plan)';
}
