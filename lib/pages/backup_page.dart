import 'package:flutter/material.dart';

import '../models/mock_exam.dart';
import '../models/study_revision.dart';
import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../models/task.dart';
import '../services/app_settings_controller.dart';
import '../services/backup_export_service.dart';
import '../services/study_session_storage.dart';
import '../services/task_storage.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.settingsController,
    required this.taskStorage,
    required this.studyStorage,
    this.exportService,
  });

  final AppSettingsController settingsController;
  final TaskStorage taskStorage;
  final StudySessionStorage studyStorage;
  final BackupExportService? exportService;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  BackupExportResult? _result;
  var _isExporting = false;

  Future<void> _export() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final values = await Future.wait<Object>([
        widget.taskStorage.getTasks(),
        widget.studyStorage.getSessions(),
        widget.studyStorage.getWeeklyGoals(),
        widget.studyStorage.getRevisions(),
        widget.studyStorage.getMockExams(),
      ]);
      final result = await (widget.exportService ?? BackupExportService())
          .exportAll(
            BackupExportData(
              settings: widget.settingsController.settings,
              tasks: values[0] as List<Task>,
              sessions: values[1] as List<StudySession>,
              weeklyGoals: values[2] as List<StudyWeeklyGoal>,
              revisions: values[3] as List<StudyRevision>,
              mockExams: values[4] as List<MockExam>,
            ),
          );
      if (!mounted) return;
      setState(() => _result = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup e relatórios criados.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível criar os arquivos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup e exportação')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crie cópias locais das tarefas, sessões, metas, revisões e simulados.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.backup_outlined),
                          title: Text('Backup completo (JSON)'),
                          subtitle: Text(
                            'Mantém todos os dados para guardar uma cópia local.',
                          ),
                        ),
                        const Divider(),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.table_chart_outlined),
                          title: Text('Planilha (CSV)'),
                          subtitle: Text(
                            'Inclui sessões, metas e simulados para abrir no Excel ou Sheets.',
                          ),
                        ),
                        const Divider(),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.picture_as_pdf_outlined),
                          title: Text('Relatório (PDF)'),
                          subtitle: Text(
                            'Resumo das metas, sessões e simulados.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('create-backup-button'),
                          onPressed: _isExporting ? null : _export,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_download_outlined),
                          label: Text(
                            _isExporting
                                ? 'Criando arquivos...'
                                : 'Criar backup e relatórios',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arquivos salvos',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text('Pasta: ${_result!.directoryPath}'),
                          const SizedBox(height: 8),
                          SelectableText(_result!.backupFile.path),
                          SelectableText(_result!.csvFile.path),
                          SelectableText(_result!.pdfFile.path),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
