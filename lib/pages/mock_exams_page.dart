import 'package:flutter/material.dart';

import '../models/mock_exam.dart';
import '../services/mock_exam_analytics.dart';
import '../services/study_session_storage.dart';

class MockExamsPage extends StatefulWidget {
  const MockExamsPage({super.key, required this.storage});

  final StudySessionStorage storage;

  @override
  State<MockExamsPage> createState() => _MockExamsPageState();
}

class _MockExamsPageState extends State<MockExamsPage> {
  final _analytics = const MockExamAnalytics();
  List<MockExam> _exams = const [];
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      final exams = await widget.storage.getMockExams();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Não foi possível carregar os simulados.');
    }
  }

  Future<void> _createExam() async {
    final exam = await Navigator.push<MockExam>(
      context,
      MaterialPageRoute(builder: (context) => const _MockExamFormPage()),
    );
    if (exam == null) return;
    try {
      await widget.storage.saveMockExam(exam);
      if (!mounted) return;
      setState(() {
        _exams = [..._exams.where((current) => current.id != exam.id), exam]
          ..sort((first, second) => second.takenAt.compareTo(first.takenAt));
      });
      _showMessage('Simulado registrado.');
    } catch (_) {
      _showMessage('Não foi possível salvar o simulado.');
    }
  }

  Future<void> _deleteExam(MockExam exam) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Excluir simulado?'),
        content: Text('Remover "${exam.title}" do seu histórico?'),
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
      await widget.storage.deleteMockExam(exam.id);
      if (!mounted) return;
      setState(
        () => _exams = _exams.where((item) => item.id != exam.id).toList(),
      );
      _showMessage('Simulado removido.');
    } catch (_) {
      _showMessage('Não foi possível remover o simulado.');
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
    final overview = _analytics.summarize(_exams);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulados')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-mock-exam-button'),
        onPressed: _createExam,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Registre provas, descubra seus pontos de atenção e acompanhe a evolução.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 20),
                        if (_exams.isEmpty)
                          const _EmptyMockExams()
                        else ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final overviewCard = _MockExamOverviewCard(
                                overview: overview,
                              );
                              if (overview.subjects.isEmpty ||
                                  constraints.maxWidth < 860) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    overviewCard,
                                    if (overview.subjects.isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      Text(
                                        'Acertos por matéria',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      _SubjectPerformanceCard(
                                        subjects: overview.subjects,
                                      ),
                                    ],
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: overviewCard),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _TabletSubjectPerformance(
                                      subjects: overview.subjects,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Evolução por prova',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          for (final exam in overview.exams)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MockExamCard(
                                exam: exam,
                                onDelete: () => _deleteExam(exam),
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
}

class _MockExamOverviewCard extends StatelessWidget {
  const _MockExamOverviewCard({required this.overview});

  final MockExamOverview overview;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_percentage(overview.accuracy)} de aproveitamento geral',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: overview.accuracy, minHeight: 8),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _OverviewMetric(
                label: 'Simulados',
                value: '${overview.exams.length}',
              ),
              _OverviewMetric(
                label: 'Acertos',
                value: '${overview.correctAnswers}/${overview.totalQuestions}',
              ),
              if (overview.latest != null)
                _OverviewMetric(
                  label: 'Último',
                  value: _formatDate(overview.latest!.takenAt),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _SubjectPerformanceCard extends StatelessWidget {
  const _SubjectPerformanceCard({required this.subjects});

  final List<MockExamSubjectPerformance> subjects;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: subjects
            .map(
              (subject) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(subject.subject)),
                        Text(
                          '${_percentage(subject.accuracy)} · ${subject.correctAnswers}/${subject.totalQuestions}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: subject.accuracy,
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _TabletSubjectPerformance extends StatelessWidget {
  const _TabletSubjectPerformance({required this.subjects});

  final List<MockExamSubjectPerformance> subjects;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Acertos por matéria',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      _SubjectPerformanceCard(subjects: subjects),
    ],
  );
}

class _MockExamCard extends StatelessWidget {
  const _MockExamCard({required this.exam, required this.onDelete});

  final MockExam exam;
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
                      exam.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        _formatDate(exam.takenAt),
                        if (exam.studyPlan != null) exam.studyPlan!,
                        if (exam.duration > Duration.zero)
                          _formatDuration(exam.duration),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir simulado',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_percentage(exam.accuracy)} · ${exam.correctAnswers}/${exam.totalQuestions} questões',
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: exam.accuracy, minHeight: 7),
          if (exam.subjectResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              exam.subjectResults
                  .map(
                    (result) =>
                        '${result.subject}: ${result.correctAnswers}/${result.totalQuestions}',
                  )
                  .join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (exam.notes != null) ...[
            const SizedBox(height: 8),
            Text(exam.notes!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    ),
  );
}

class _EmptyMockExams extends StatelessWidget {
  const _EmptyMockExams();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.quiz_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Registre seu primeiro simulado para acompanhar notas, acertos e matérias que precisam de revisão.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MockExamFormPage extends StatefulWidget {
  const _MockExamFormPage();

  @override
  State<_MockExamFormPage> createState() => _MockExamFormPageState();
}

class _MockExamFormPageState extends State<_MockExamFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _planController = TextEditingController();
  final _questionsController = TextEditingController();
  final _correctController = TextEditingController();
  final _minutesController = TextEditingController();
  final _notesController = TextEditingController();
  final _subjectController = TextEditingController();
  final _subjectQuestionsController = TextEditingController();
  final _subjectCorrectController = TextEditingController();
  final _subjectResults = <MockExamSubjectResult>[];
  var _takenAt = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _planController.dispose();
    _questionsController.dispose();
    _correctController.dispose();
    _minutesController.dispose();
    _notesController.dispose();
    _subjectController.dispose();
    _subjectQuestionsController.dispose();
    _subjectCorrectController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _takenAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _takenAt = date);
  }

  void _addSubjectResult() {
    final subject = _subjectController.text.trim();
    final questions = int.tryParse(_subjectQuestionsController.text.trim());
    final correct = int.tryParse(_subjectCorrectController.text.trim());
    if (subject.isEmpty ||
        questions == null ||
        questions <= 0 ||
        correct == null ||
        correct < 0 ||
        correct > questions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha uma matéria com questões e acertos válidos.'),
        ),
      );
      return;
    }
    setState(() {
      _subjectResults.add(
        MockExamSubjectResult(
          subject: subject,
          totalQuestions: questions,
          correctAnswers: correct,
        ),
      );
      _subjectController.clear();
      _subjectQuestionsController.clear();
      _subjectCorrectController.clear();
    });
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    final questions = int.parse(_questionsController.text.trim());
    final correct = int.parse(_correctController.text.trim());
    if (correct > questions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Os acertos não podem superar as questões.'),
        ),
      );
      return;
    }
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final exam = MockExam(
      id: 'mock-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text,
      studyPlan: _planController.text.trim().isEmpty
          ? null
          : _planController.text.trim(),
      takenAt: _takenAt,
      totalQuestions: questions,
      correctAnswers: correct,
      duration: Duration(minutes: minutes.clamp(0, 24 * 60)),
      subjectResults: _subjectResults,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    Navigator.pop(context, exam);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar simulado')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('mock-exam-title-field'),
                    controller: _titleController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do simulado',
                      hintText: 'Ex.: ITA 2025 — Dia 1',
                      prefixIcon: Icon(Icons.quiz_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe o nome do simulado.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _planController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Prova ou objetivo (opcional)',
                      hintText: 'Ex.: ITA',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Data: ${_formatDate(_takenAt)}'),
                  ),
                  const SizedBox(height: 12),
                  _NumberField(
                    keyName: 'mock-exam-questions-field',
                    controller: _questionsController,
                    label: 'Total de questões',
                    icon: Icons.format_list_numbered,
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _NumberField(
                    keyName: 'mock-exam-correct-field',
                    controller: _correctController,
                    label: 'Acertos',
                    icon: Icons.task_alt_outlined,
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _NumberField(
                    keyName: 'mock-exam-minutes-field',
                    controller: _minutesController,
                    label: 'Tempo gasto (opcional)',
                    suffix: 'min',
                    icon: Icons.timer_outlined,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Acertos por matéria (opcional)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _subjectController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Matéria',
                      hintText: 'Ex.: Matemática',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          keyName: 'mock-exam-subject-questions-field',
                          controller: _subjectQuestionsController,
                          label: 'Questões',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumberField(
                          keyName: 'mock-exam-subject-correct-field',
                          controller: _subjectCorrectController,
                          label: 'Acertos',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('mock-exam-add-subject-button'),
                    onPressed: _addSubjectResult,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar matéria'),
                  ),
                  if (_subjectResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: List.generate(_subjectResults.length, (index) {
                        final result = _subjectResults[index];
                        return InputChip(
                          label: Text(
                            '${result.subject}: ${result.correctAnswers}/${result.totalQuestions}',
                          ),
                          onDeleted: () =>
                              setState(() => _subjectResults.removeAt(index)),
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Anotações e pontos para revisar (opcional)',
                      hintText: 'Ex.: revisar funções e cinemática.',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('save-mock-exam-button'),
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar simulado'),
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

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.keyName,
    required this.controller,
    required this.label,
    this.icon,
    this.suffix,
    this.required = false,
  });

  final String keyName;
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? suffix;
  final bool required;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey(keyName),
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      prefixIcon: icon == null ? null : Icon(icon),
    ),
    validator: required
        ? (value) {
            final parsed = int.tryParse(value?.trim() ?? '');
            return parsed == null || parsed <= 0
                ? 'Informe um número válido.'
                : null;
          }
        : null,
  );
}

String _percentage(double value) => '${(value * 100).round()}%';

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours == 0
      ? '$minutes min'
      : '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}
