import 'package:flutter/material.dart';

import '../models/task.dart';
import '../widgets/task_card.dart';

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key, this.task, this.initialDate});

  final Task? task;
  final DateTime? initialDate;

  static const double _formMaxWidth = 640;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  static const _subjectSuggestions = [
    'Matemática',
    'Português',
    'Física',
    'Química',
    'Biologia',
    'História',
    'Geografia',
    'Inglês',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _subjectController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TaskPriority _selectedPriority;
  late TaskCategory _selectedCategory;
  late ReminderOffset _selectedReminderOffset;
  late TaskRecurrence _selectedRecurrence;
  late Set<int> _selectedWeekdays;
  var _showWeekdayValidation = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final initialDateTime = task?.dateTime ?? _initialDateTime();
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _subjectController = TextEditingController(text: task?.subject ?? '');
    _selectedDate = DateTime(
      initialDateTime.year,
      initialDateTime.month,
      initialDateTime.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);
    _selectedPriority = task?.priority ?? TaskPriority.medium;
    _selectedCategory = task?.category ?? TaskCategory.other;
    _selectedReminderOffset = task?.reminderOffset ?? ReminderOffset.atTime;
    _selectedRecurrence = task?.recurrence ?? TaskRecurrence.none;
    _selectedWeekdays = Set.of(task?.recurrenceWeekdays ?? const []);
  }

  DateTime _initialDateTime() {
    final now = DateTime.now();
    final selectedDate = widget.initialDate;
    if (selectedDate == null) return now.add(const Duration(hours: 1));

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (selectedDate == null) return;
    setState(() {
      _selectedDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
  }

  Future<void> _pickTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (selectedTime == null) return;
    setState(() => _selectedTime = selectedTime);
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRecurrence == TaskRecurrence.customWeekdays &&
        _selectedWeekdays.isEmpty) {
      setState(() => _showWeekdayValidation = true);
      return;
    }

    final now = DateTime.now();
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final description = _descriptionController.text.trim();
    final subject = _subjectController.text.trim();
    final recurrenceWeekdays =
        _selectedRecurrence == TaskRecurrence.customWeekdays
        ? (_selectedWeekdays.toList()..sort())
        : const <int>[];
    final currentTask = widget.task;
    final task = currentTask == null
        ? Task(
            id: 'task-${now.microsecondsSinceEpoch}',
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            subject: subject.isEmpty ? null : subject,
            dateTime: dateTime,
            priority: _selectedPriority,
            category: _selectedCategory,
            reminderOffset: _selectedReminderOffset,
            recurrence: _selectedRecurrence,
            recurrenceWeekdays: recurrenceWeekdays,
            createdAt: now,
          )
        : currentTask.copyWith(
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            subject: subject.isEmpty ? null : subject,
            dateTime: dateTime,
            priority: _selectedPriority,
            category: _selectedCategory,
            reminderOffset: _selectedReminderOffset,
            recurrence: _selectedRecurrence,
            recurrenceWeekdays: recurrenceWeekdays,
          );

    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar tarefa' : 'Nova tarefa';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TaskFormPage._formMaxWidth,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing
                          ? 'Atualize os detalhes da sua tarefa.'
                          : 'Planeje sua próxima sessão de estudo.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FormSection(
                      title: 'Detalhes',
                      icon: Icons.edit_note_rounded,
                      child: Column(
                        children: [
                          TextFormField(
                            key: const ValueKey('task-title-field'),
                            controller: _titleController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Título',
                              hintText: 'Ex.: Revisar cálculo',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe um título para a tarefa.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const ValueKey('task-subject-field'),
                            controller: _subjectController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Matéria',
                              hintText: 'Ex.: Física ou Programação',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Sugestões',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _subjectSuggestions.map((subject) {
                                return ActionChip(
                                  label: Text(subject),
                                  onPressed: () {
                                    setState(
                                      () => _subjectController.text = subject,
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const ValueKey('task-description-field'),
                            controller: _descriptionController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Descrição',
                              hintText: 'Adicione contexto, se quiser',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: 'Quando estudar',
                      icon: Icons.calendar_month_outlined,
                      child: _DateTimeFields(
                        selectedDate: _selectedDate,
                        selectedTime: _selectedTime,
                        onPickDate: _pickDate,
                        onPickTime: _pickTime,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: 'Organização',
                      icon: Icons.tune_rounded,
                      child: Column(
                        children: [
                          DropdownButtonFormField<TaskPriority>(
                            key: const ValueKey('task-priority-field'),
                            initialValue: _selectedPriority,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Prioridade',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: TaskPriority.values.map((priority) {
                              final style = priority.style(context);
                              return DropdownMenuItem(
                                value: priority,
                                child: Row(
                                  children: [
                                    Icon(
                                      style.icon,
                                      size: 18,
                                      color: style.color,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(priority.label),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (priority) {
                              if (priority != null) {
                                setState(() => _selectedPriority = priority);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<TaskCategory>(
                            key: const ValueKey('task-category-field'),
                            initialValue: _selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Categoria',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: TaskCategory.values.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              );
                            }).toList(),
                            onChanged: (category) {
                              if (category != null) {
                                setState(() => _selectedCategory = category);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<ReminderOffset>(
                            key: const ValueKey('task-reminder-field'),
                            initialValue: _selectedReminderOffset,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Lembrete',
                              prefixIcon: Icon(
                                Icons.notifications_none_rounded,
                              ),
                            ),
                            items: ReminderOffset.values.map((reminderOffset) {
                              return DropdownMenuItem(
                                value: reminderOffset,
                                child: Text(reminderOffset.label),
                              );
                            }).toList(),
                            onChanged: (reminderOffset) {
                              if (reminderOffset != null) {
                                setState(
                                  () =>
                                      _selectedReminderOffset = reminderOffset,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: 'Repetir',
                      icon: Icons.repeat_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<TaskRecurrence>(
                            key: const ValueKey('task-recurrence-field'),
                            initialValue: _selectedRecurrence,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Repetição',
                              prefixIcon: Icon(Icons.repeat_rounded),
                            ),
                            items: TaskRecurrence.values.map((recurrence) {
                              return DropdownMenuItem(
                                value: recurrence,
                                child: Text(recurrence.label),
                              );
                            }).toList(),
                            onChanged: (recurrence) {
                              if (recurrence == null) return;
                              setState(() {
                                _selectedRecurrence = recurrence;
                                _showWeekdayValidation = false;
                              });
                            },
                          ),
                          if (_selectedRecurrence ==
                              TaskRecurrence.customWeekdays) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Dias da semana',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(7, (index) {
                                final weekday = index + DateTime.monday;
                                return FilterChip(
                                  key: ValueKey('recurrence-weekday-$weekday'),
                                  label: Text(weekdayShortLabel(weekday)),
                                  selected: _selectedWeekdays.contains(weekday),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWeekdays.add(weekday);
                                      } else {
                                        _selectedWeekdays.remove(weekday);
                                      }
                                      _showWeekdayValidation = false;
                                    });
                                  },
                                );
                              }),
                            ),
                            if (_showWeekdayValidation) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Selecione ao menos um dia da semana.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const ValueKey('save-task-button'),
                      onPressed: _saveTask,
                      icon: Icon(
                        _isEditing ? Icons.save_outlined : Icons.add_task,
                      ),
                      label: Text(
                        _isEditing ? 'Salvar alterações' : 'Salvar tarefa',
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

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DateTimeFields extends StatelessWidget {
  const _DateTimeFields({
    required this.selectedDate,
    required this.selectedTime,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final dateButton = OutlinedButton.icon(
          key: const ValueKey('task-date-button'),
          onPressed: onPickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_formatDate(selectedDate)),
        );
        final timeButton = OutlinedButton.icon(
          key: const ValueKey('task-time-button'),
          onPressed: onPickTime,
          icon: const Icon(Icons.schedule_outlined),
          label: Text(_formatTime(selectedTime)),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [dateButton, const SizedBox(height: 12), timeButton],
          );
        }
        return Row(
          children: [
            Expanded(child: dateButton),
            const SizedBox(width: 12),
            Expanded(child: timeButton),
          ],
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

extension ReminderOffsetLabel on ReminderOffset {
  String get label {
    return switch (this) {
      ReminderOffset.atTime => 'No horário',
      ReminderOffset.tenMinutes => '10 minutos antes',
      ReminderOffset.thirtyMinutes => '30 minutos antes',
      ReminderOffset.oneHour => '1 hora antes',
    };
  }
}
