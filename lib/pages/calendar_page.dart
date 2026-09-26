import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/task_notification_scheduler.dart';
import '../services/task_recurrence_service.dart';
import '../services/task_storage.dart';
import '../services/task_storage_service.dart';
import '../widgets/task_card.dart';
import 'task_form_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    this.initialTasks,
    this.storage,
    this.notifications,
    this.initialSelectedDate,
  });

  final List<Task>? initialTasks;
  final TaskStorage? storage;
  final TaskNotificationScheduler? notifications;
  final DateTime? initialSelectedDate;

  static const double _desktopMaxWidth = 1180;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final TaskStorage _storage;
  late final TaskNotificationScheduler _notifications;
  final _recurrenceService = TaskRecurrenceService();
  final _changingTaskIds = <String>{};
  late List<Task> _tasks;
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? TaskStorageService.instance();
    _notifications = widget.notifications ?? NotificationService.instance;
    _selectedDate = _dateOnly(widget.initialSelectedDate ?? DateTime.now());
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _tasks = List.of(widget.initialTasks ?? const []);

    if (widget.initialTasks != null) {
      _isLoading = false;
      return;
    }
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _storage.getTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Não foi possível carregar as tarefas.');
    }
  }

  Future<void> _createTask() async {
    final task = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormPage(initialDate: _selectedDate),
      ),
    );
    if (task == null) return;

    try {
      await _storage.saveTask(task);
      await _scheduleNotification(task);
      if (!mounted) return;
      setState(() => _tasks = [..._tasks, task]);
    } catch (_) {
      _showMessage('Não foi possível salvar a tarefa.');
    }
  }

  Future<void> _editTask(Task task) async {
    final editedTask = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (context) => TaskFormPage(task: task)),
    );
    if (editedTask == null) return;

    try {
      await _cancelNotification(task.id);
      await _storage.updateTask(editedTask);
      await _scheduleNotification(editedTask);
      if (!mounted) return;
      setState(() => _replaceTask(editedTask));
    } catch (_) {
      _showMessage('Não foi possível salvar a tarefa.');
    }
  }

  Future<void> _toggleTaskCompletion(Task task, bool isCompleted) async {
    if (_changingTaskIds.contains(task.id) || task.isCompleted == isCompleted) {
      return;
    }
    _changingTaskIds.add(task.id);
    final updatedTask = task.copyWith(
      isCompleted: isCompleted,
      completedAt: isCompleted ? DateTime.now() : null,
    );

    try {
      await _storage.updateTask(updatedTask);
      if (updatedTask.isCompleted) {
        await _cancelNotification(updatedTask.id);
      } else {
        await _scheduleNotification(updatedTask);
      }
      if (!mounted) return;
      setState(() => _replaceTask(updatedTask));

      if (!updatedTask.isCompleted) return;
      final nextTask = _recurrenceService.createNextOccurrence(updatedTask);
      if (nextTask == null) return;

      try {
        await _storage.saveTask(nextTask);
        await _scheduleNotification(nextTask);
        if (!mounted) return;
        setState(() => _tasks = [..._tasks, nextTask]);
      } catch (_) {
        _showMessage('Tarefa concluída, mas não foi possível criar a próxima.');
      }
    } catch (_) {
      _showMessage('Não foi possível atualizar a tarefa.');
    } finally {
      _changingTaskIds.remove(task.id);
    }
  }

  Future<void> _confirmDeleteTask(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Excluir tarefa?'),
        content: Text('Tem certeza de que deseja excluir "${task.title}"?'),
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
      await _storage.deleteTask(task.id);
      await _cancelNotification(task.id);
      if (!mounted) return;
      setState(
        () => _tasks = _tasks.where((item) => item.id != task.id).toList(),
      );
    } catch (_) {
      _showMessage('Não foi possível excluir a tarefa.');
    }
  }

  void _replaceTask(Task updatedTask) {
    _tasks = [
      for (final task in _tasks)
        if (task.id == updatedTask.id) updatedTask else task,
    ];
  }

  Future<void> _scheduleNotification(Task task) async {
    try {
      await _notifications.scheduleTaskNotification(task);
    } on NotificationUnavailableException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Tarefa salva, mas não foi possível agendar o lembrete.');
    }
  }

  Future<void> _cancelNotification(String taskId) async {
    try {
      await _notifications.cancelTaskNotification(taskId);
    } catch (_) {
      _showMessage('Não foi possível cancelar o lembrete.');
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
    final tasksForSelectedDate =
        _tasks
            .where((task) => _isSameDay(task.dateTime, _selectedDate))
            .toList()
          ..sort((first, second) => first.dateTime.compareTo(second.dateTime));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('calendar-new-task-button'),
        onPressed: _createTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova tarefa'),
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: CalendarPage._desktopMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MonthHeader(
                          displayedMonth: _displayedMonth,
                          onPrevious: () {
                            setState(() {
                              _displayedMonth = DateTime(
                                _displayedMonth.year,
                                _displayedMonth.month - 1,
                              );
                            });
                          },
                          onNext: () {
                            setState(() {
                              _displayedMonth = DateTime(
                                _displayedMonth.year,
                                _displayedMonth.month + 1,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final calendar = _MonthCalendar(
                              displayedMonth: _displayedMonth,
                              selectedDate: _selectedDate,
                              tasks: _tasks,
                              onSelectDate: (date) {
                                setState(() => _selectedDate = _dateOnly(date));
                              },
                            );
                            final selectedTasks = _SelectedDayTasks(
                              selectedDate: _selectedDate,
                              tasks: tasksForSelectedDate,
                              onTaskChanged: _toggleTaskCompletion,
                              onEdit: _editTask,
                              onDelete: _confirmDeleteTask,
                            );
                            if (constraints.maxWidth < 860) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  calendar,
                                  const SizedBox(height: 28),
                                  selectedTasks,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: calendar),
                                const SizedBox(width: 24),
                                Expanded(flex: 5, child: selectedTasks),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  static DateTime _dateOnly(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _formatSelectedDate(DateTime date) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    return '${date.day} de ${months[date.month - 1]}';
  }
}

class _SelectedDayTasks extends StatelessWidget {
  const _SelectedDayTasks({
    required this.selectedDate,
    required this.tasks,
    required this.onTaskChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime selectedDate;
  final List<Task> tasks;
  final void Function(Task task, bool isCompleted) onTaskChanged;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _CalendarPageState._formatSelectedDate(selectedDate),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        '${tasks.length} ${tasks.length == 1 ? 'tarefa' : 'tarefas'}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 14),
      if (tasks.isEmpty)
        const _CalendarEmptyDay()
      else
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TaskCard(
              key: ValueKey('calendar-task-card-${task.id}'),
              task: task,
              onChanged: (isCompleted) => onTaskChanged(task, isCompleted),
              onEdit: () => onEdit(task),
              onDelete: () => onDelete(task),
            ),
          ),
    ],
  );
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.displayedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime displayedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('calendar-previous-month-button'),
          tooltip: 'Mês anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            _monthLabel(displayedMonth),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          key: const ValueKey('calendar-next-month-button'),
          tooltip: 'Próximo mês',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.displayedMonth,
    required this.selectedDate,
    required this.tasks,
    required this.onSelectDate,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final List<Task> tasks;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(
      displayedMonth.year,
      displayedMonth.month,
      1,
    ).weekday;
    final daysInMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    ).day;
    final cellCount = ((firstWeekday - 1 + daysInMonth + 6) ~/ 7) * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                for (final weekday in [
                  'Seg',
                  'Ter',
                  'Qua',
                  'Qui',
                  'Sex',
                  'Sáb',
                  'Dom',
                ])
                  Expanded(child: Center(child: Text(weekday))),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                final day = index - (firstWeekday - 1) + 1;
                if (day < 1 || day > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(
                  displayedMonth.year,
                  displayedMonth.month,
                  day,
                );
                final hasTasks = tasks.any(
                  (task) => _isSameDay(task.dateTime, date),
                );
                final isSelected = _isSameDay(selectedDate, date);
                final isToday = _isSameDay(DateTime.now(), date);
                final colorScheme = Theme.of(context).colorScheme;

                return Semantics(
                  selected: isSelected,
                  label: '${date.day}${hasTasks ? ', possui tarefas' : ''}',
                  child: InkWell(
                    key: ValueKey(
                      'calendar-day-${date.year}-${date.month}-${date.day}',
                    ),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelectDate(date),
                    child: Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          border: isToday && !isSelected
                              ? Border.all(color: colorScheme.primary)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : null,
                                  ),
                            ),
                            if (hasTasks)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              const SizedBox(height: 5),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _CalendarEmptyDay extends StatelessWidget {
  const _CalendarEmptyDay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Text('Nenhuma tarefa neste dia.'),
      ),
    );
  }
}
