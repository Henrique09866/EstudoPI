import 'package:flutter/material.dart';

import '../models/study_session.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/task_notification_scheduler.dart';
import '../services/task_recurrence_service.dart';
import '../services/task_storage.dart';
import '../services/task_storage_service.dart';
import '../services/study_session_storage.dart';
import '../services/study_session_storage_service.dart';
import '../services/study_session_summary.dart';
import '../services/app_settings_controller.dart';
import '../widgets/task_card.dart';
import '../widgets/task_filter_sheet.dart';
import 'calendar_page.dart';
import 'progress_page.dart';
import 'study_page.dart';
import 'settings_page.dart';
import 'task_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialTasks,
    this.storage,
    this.notifications,
    this.studyStorage,
    this.settingsController,
  });

  final List<Task>? initialTasks;
  final TaskStorage? storage;
  final TaskNotificationScheduler? notifications;
  final StudySessionStorage? studyStorage;
  final AppSettingsController? settingsController;

  static const double _desktopMaxWidth = 760;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TaskStorage _storage;
  late final TaskNotificationScheduler _notifications;
  late final StudySessionStorage? _studyStorage;
  final _searchController = TextEditingController();
  final _recurrenceService = TaskRecurrenceService();
  final _changingTaskIds = <String>{};
  late List<Task> _tasks;
  var _filters = const TaskFilters();
  var _isLoading = true;
  var _searchQuery = '';
  var _studyMinutesToday = 0;
  var _dailyStudyGoalMinutes =
      StudySessionStorageService.defaultDailyGoalMinutes;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? TaskStorageService.instance();
    _notifications = widget.notifications ?? NotificationService.instance;
    _studyStorage = widget.studyStorage ?? _availableStudyStorage();
    _tasks = List.of(widget.initialTasks ?? const []);

    if (widget.initialTasks != null) {
      _isLoading = false;
      return;
    }

    _loadTasks();
    _loadStudySummary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _storage.getTasks();
      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
      await _reconcileNotifications(tasks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showStorageError('Não foi possível carregar as tarefas.');
    }
  }

  Future<void> _loadStudySummary() async {
    final storage = _studyStorage;
    if (storage == null) return;
    try {
      final results = await Future.wait<Object>([
        storage.getSessions(),
        storage.getDailyGoalMinutes(),
      ]);
      final duration = StudySessionSummary.totalForDay(
        results[0] as List<StudySession>,
        DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _studyMinutesToday = duration.inMinutes;
        _dailyStudyGoalMinutes = results[1] as int;
      });
    } catch (_) {
      // A falha no resumo não deve impedir o gerenciamento de tarefas.
    }
  }

  StudySessionStorage? _availableStudyStorage() {
    try {
      return StudySessionStorageService.instance();
    } catch (_) {
      return null;
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
      setState(() {
        _tasks = [
          for (final item in _tasks)
            if (item.id == task.id) updatedTask else item,
        ];
      });
      if (!updatedTask.isCompleted) return;

      final nextTask = _recurrenceService.createNextOccurrence(updatedTask);
      if (nextTask == null) return;

      try {
        await _storage.saveTask(nextTask);
        await _scheduleNotification(nextTask);
        if (!mounted) return;
        setState(() => _tasks = [..._tasks, nextTask]);
      } catch (_) {
        _showStorageError(
          'Tarefa concluída, mas não foi possível criar a próxima.',
        );
      }
    } catch (_) {
      _showStorageError('Não foi possível atualizar a tarefa.');
    } finally {
      _changingTaskIds.remove(task.id);
    }
  }

  Future<void> _createTask() async {
    final task = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (context) => const TaskFormPage()),
    );
    if (task == null) return;

    try {
      await _storage.saveTask(task);
      await _scheduleNotification(task);
      if (!mounted) return;
      setState(() => _tasks = [..._tasks, task]);
    } catch (_) {
      _showStorageError('Não foi possível salvar a tarefa.');
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
      setState(() {
        _tasks = [
          for (final item in _tasks)
            if (item.id == editedTask.id) editedTask else item,
        ];
      });
    } catch (_) {
      _showStorageError('Não foi possível salvar a tarefa.');
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
      _showStorageError('Não foi possível excluir a tarefa.');
    }
  }

  Future<void> _openFilters() async {
    final subjects =
        _tasks
            .map((task) => task.subject?.trim())
            .whereType<String>()
            .where((subject) => subject.isNotEmpty)
            .toSet()
            .toList()
          ..sort((first, second) => first.compareTo(second));
    final filters = await showModalBottomSheet<TaskFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          TaskFilterSheet(initialFilters: _filters, subjects: subjects),
    );
    if (filters == null || !mounted) return;
    setState(() => _filters = filters);
  }

  Future<void> _openCalendar() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarPage(
          initialTasks: _tasks,
          storage: _storage,
          notifications: _notifications,
        ),
      ),
    );
    if (mounted) await _loadTasks();
  }

  Future<void> _openStudy() async {
    final subjects =
        _tasks
            .map((task) => task.subject?.trim())
            .whereType<String>()
            .where((subject) => subject.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StudyPage(storage: _studyStorage, subjects: subjects),
      ),
    );
    if (mounted) await _loadStudySummary();
  }

  Future<void> _openProgress() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProgressPage(tasks: List.of(_tasks), storage: _studyStorage),
      ),
    );
  }

  Future<void> _openSettings() async {
    final controller = widget.settingsController;
    if (controller == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(controller: controller),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filters = const TaskFilters();
    });
  }

  void _showStorageError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reconcileNotifications(List<Task> tasks) async {
    try {
      await _notifications.reconcileTaskNotifications(tasks);
    } on NotificationUnavailableException catch (error) {
      _showNotificationMessage(error.message);
    } catch (_) {
      _showNotificationMessage('Não foi possível atualizar os lembretes.');
    }
  }

  Future<void> _scheduleNotification(Task task) async {
    try {
      await _notifications.scheduleTaskNotification(task);
    } on NotificationUnavailableException catch (error) {
      _showNotificationMessage(error.message);
    } catch (_) {
      _showNotificationMessage(
        'Tarefa salva, mas não foi possível agendar o lembrete.',
      );
    }
  }

  Future<void> _cancelNotification(String taskId) async {
    try {
      await _notifications.cancelTaskNotification(taskId);
    } catch (_) {
      _showNotificationMessage('Não foi possível cancelar o lembrete.');
    }
  }

  void _showNotificationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visibleTasks = _tasks.where(_matchesCurrentSearchAndFilters).toList();
    final overdueTasks = visibleTasks.where((task) => task.isOverdue).toList()
      ..sort(_compareByDateTime);
    final todayTasks =
        visibleTasks
            .where(
              (task) =>
                  task.isPending &&
                  !task.isOverdue &&
                  _isSameDay(task.dateTime, now),
            )
            .toList()
          ..sort(_compareByDateTime);
    final upcomingTasks =
        visibleTasks
            .where(
              (task) => task.isPending && _isAfterToday(task.dateTime, now),
            )
            .toList()
          ..sort(_compareByDateTime);
    final completedTasks =
        visibleTasks.where((task) => task.isCompleted).toList()
          ..sort(_compareByDateTime);
    final allCompletedTasks = _tasks.where((task) => task.isCompleted).toList();
    final completedToday = allCompletedTasks
        .where((task) => _isSameDay(task.dateTime, now))
        .toList();
    final todayPendingCount = _tasks
        .where((task) => task.isPending && _isSameDay(task.dateTime, now))
        .length;
    final overdueCount = _tasks.where((task) => task.isOverdue).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-task-button'),
        onPressed: _createTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova tarefa'),
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: HomePage._desktopMaxWidth,
                    ),
                    child: _HomeContent(
                      allTasksAreEmpty: _tasks.isEmpty,
                      noResults: _tasks.isNotEmpty && visibleTasks.isEmpty,
                      overdueTasks: overdueTasks,
                      todayTasks: todayTasks,
                      upcomingTasks: upcomingTasks,
                      completedTasks: completedTasks,
                      completedToday: completedToday,
                      todayPendingCount: todayPendingCount,
                      overdueCount: overdueCount,
                      searchController: _searchController,
                      filters: _filters,
                      onSearchChanged: (query) {
                        setState(() => _searchQuery = query);
                      },
                      onOpenFilters: _openFilters,
                      onOpenCalendar: _openCalendar,
                      onOpenStudy: _openStudy,
                      onOpenProgress: _openProgress,
                      onOpenSettings: _openSettings,
                      studyMinutesToday: _studyMinutesToday,
                      dailyStudyGoalMinutes: _dailyStudyGoalMinutes,
                      onClearFilters: _clearFilters,
                      onTaskChanged: _toggleTaskCompletion,
                      onEditTask: _editTask,
                      onDeleteTask: _confirmDeleteTask,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  bool _matchesCurrentSearchAndFilters(Task task) {
    final query = _searchQuery.trim().toLowerCase();
    final matchesSearch =
        query.isEmpty ||
        task.title.toLowerCase().contains(query) ||
        (task.description?.toLowerCase().contains(query) ?? false) ||
        (task.subject?.toLowerCase().contains(query) ?? false);
    if (!matchesSearch) return false;

    final matchesStatus = switch (_filters.status) {
      TaskStatusFilter.all => true,
      TaskStatusFilter.pending => task.isPending,
      TaskStatusFilter.completed => task.isCompleted,
      TaskStatusFilter.overdue => task.isOverdue,
    };
    final selectedSubject = _filters.subject?.trim().toLowerCase();
    final matchesSubject =
        selectedSubject == null ||
        selectedSubject.isEmpty ||
        task.subject?.trim().toLowerCase() == selectedSubject;

    return matchesStatus &&
        (_filters.priority == null || task.priority == _filters.priority) &&
        (_filters.category == null || task.category == _filters.category) &&
        matchesSubject;
  }

  static bool _isSameDay(DateTime firstDate, DateTime secondDate) =>
      firstDate.year == secondDate.year &&
      firstDate.month == secondDate.month &&
      firstDate.day == secondDate.day;

  static bool _isAfterToday(DateTime dateTime, DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return !dateTime.isBefore(tomorrow);
  }

  static int _compareByDateTime(Task firstTask, Task secondTask) =>
      firstTask.dateTime.compareTo(secondTask.dateTime);
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.allTasksAreEmpty,
    required this.noResults,
    required this.overdueTasks,
    required this.todayTasks,
    required this.upcomingTasks,
    required this.completedTasks,
    required this.completedToday,
    required this.todayPendingCount,
    required this.overdueCount,
    required this.searchController,
    required this.filters,
    required this.onSearchChanged,
    required this.onOpenFilters,
    required this.onOpenCalendar,
    required this.onOpenStudy,
    required this.onOpenProgress,
    required this.onOpenSettings,
    required this.studyMinutesToday,
    required this.dailyStudyGoalMinutes,
    required this.onClearFilters,
    required this.onTaskChanged,
    required this.onEditTask,
    required this.onDeleteTask,
  });

  final bool allTasksAreEmpty;
  final bool noResults;
  final List<Task> overdueTasks;
  final List<Task> todayTasks;
  final List<Task> upcomingTasks;
  final List<Task> completedTasks;
  final List<Task> completedToday;
  final int todayPendingCount;
  final int overdueCount;
  final TextEditingController searchController;
  final TaskFilters filters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenSettings;
  final int studyMinutesToday;
  final int dailyStudyGoalMinutes;
  final VoidCallback onClearFilters;
  final void Function(Task task, bool isCompleted) onTaskChanged;
  final ValueChanged<Task> onEditTask;
  final ValueChanged<Task> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalToday = todayPendingCount + completedToday.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Estudo Pi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('open-progress-button'),
              tooltip: 'Abrir meu progresso',
              onPressed: onOpenProgress,
              icon: const Icon(Icons.insights_outlined),
            ),
            IconButton(
              key: const ValueKey('open-calendar-button'),
              tooltip: 'Abrir calendário',
              onPressed: onOpenCalendar,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            IconButton(
              key: const ValueKey('open-settings-button'),
              tooltip: 'Abrir configurações',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          '${_greeting()} 👋',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Vamos organizar seus estudos.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _TodaySummary(
          pendingCount: todayPendingCount,
          completedCount: completedToday.length,
          overdueCount: overdueCount,
          totalCount: totalToday,
        ),
        const SizedBox(height: 16),
        _StudyHomeSummary(
          minutes: studyMinutesToday,
          goalMinutes: dailyStudyGoalMinutes,
          onPressed: onOpenStudy,
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('task-search-field'),
          controller: searchController,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Pesquisar tarefas',
            hintText: 'Título, descrição ou matéria',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              key: const ValueKey('filter-button'),
              onPressed: onOpenFilters,
              icon: const Icon(Icons.tune_rounded),
              label: Text(
                filters.isActive
                    ? 'Filtros (${filters.activeCount})'
                    : 'Filtros',
              ),
            ),
            if (filters.isActive ||
                searchController.text.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('home-clear-filters-button'),
                onPressed: onClearFilters,
                child: const Text('Limpar filtros'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),
        if (allTasksAreEmpty)
          const _EmptyTaskList()
        else if (noResults)
          _NoResults(onClearFilters: onClearFilters)
        else ...[
          if (overdueTasks.isNotEmpty)
            _TaskSection(
              title: 'Atrasadas',
              count: overdueTasks.length,
              tasks: overdueTasks,
              onTaskChanged: onTaskChanged,
              onEditTask: onEditTask,
              onDeleteTask: onDeleteTask,
            ),
          _TaskSection(
            title: 'Hoje',
            count: todayTasks.length,
            emptyMessage: 'Nenhuma tarefa para hoje',
            emptySupport: 'Você está em dia 🎉',
            emptyIcon: Icons.wb_sunny_outlined,
            tasks: todayTasks,
            onTaskChanged: onTaskChanged,
            onEditTask: onEditTask,
            onDeleteTask: onDeleteTask,
          ),
          _TaskSection(
            title: 'Próximas',
            count: upcomingTasks.length,
            emptyMessage: 'Nenhuma tarefa futura',
            emptySupport: 'Planeje sua próxima sessão quando precisar.',
            emptyIcon: Icons.event_available_outlined,
            tasks: upcomingTasks,
            onTaskChanged: onTaskChanged,
            onEditTask: onEditTask,
            onDeleteTask: onDeleteTask,
          ),
          _TaskSection(
            title: 'Concluídas',
            count: completedTasks.length,
            emptyMessage: 'Nenhuma tarefa concluída',
            emptySupport: 'Suas conquistas aparecerão aqui.',
            emptyIcon: Icons.task_alt_rounded,
            tasks: completedTasks,
            onTaskChanged: onTaskChanged,
            onEditTask: onEditTask,
            onDeleteTask: onDeleteTask,
          ),
        ],
      ],
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }
}

class _StudyHomeSummary extends StatelessWidget {
  const _StudyHomeSummary({
    required this.minutes,
    required this.goalMinutes,
    required this.onPressed,
  });

  final int minutes;
  final int goalMinutes;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = goalMinutes == 0
        ? 0.0
        : (minutes / goalMinutes).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estudo hoje',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text('$minutes min / $goalMinutes min'),
                const SizedBox(height: 7),
                LinearProgressIndicator(value: progress, minHeight: 6),
              ],
            );
            final button = TextButton(
              key: const ValueKey('start-study-from-home-button'),
              onPressed: onPressed,
              child: const Text('Iniciar estudo'),
            );
            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 6),
                  button,
                ],
              );
            }
            return Row(
              children: [
                Icon(Icons.timer_outlined, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 12),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.pendingCount,
    required this.completedCount,
    required this.overdueCount,
    required this.totalCount,
  });

  final int pendingCount;
  final int completedCount;
  final int overdueCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final percentage = (progress * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Resumo de hoje',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.insights_outlined, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _SummaryMetric(
                  icon: Icons.pending_actions_outlined,
                  value: '$pendingCount',
                  label: pendingCount == 1 ? 'pendente' : 'pendentes',
                  color: colorScheme.primary,
                ),
                _SummaryMetric(
                  icon: Icons.task_alt_rounded,
                  value: '$completedCount',
                  label: completedCount == 1 ? 'concluída' : 'concluídas',
                  color: colorScheme.tertiary,
                ),
                _SummaryMetric(
                  icon: Icons.error_outline_rounded,
                  value: '$overdueCount',
                  label: overdueCount == 1 ? 'atrasada' : 'atrasadas',
                  color: colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$completedCount de $totalCount concluídas',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('$percentage%'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.count,
    required this.tasks,
    required this.onTaskChanged,
    required this.onEditTask,
    required this.onDeleteTask,
    this.emptyMessage,
    this.emptySupport,
    this.emptyIcon,
  });

  final String title;
  final int count;
  final List<Task> tasks;
  final void Function(Task task, bool isCompleted) onTaskChanged;
  final ValueChanged<Task> onEditTask;
  final ValueChanged<Task> onDeleteTask;
  final String? emptyMessage;
  final String? emptySupport;
  final IconData? emptyIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                label: Text('$count'),
                backgroundColor: colorScheme.secondaryContainer,
                textColor: colorScheme.onSecondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty && emptyMessage != null)
            _EmptySectionMessage(
              message: emptyMessage!,
              support: emptySupport!,
              icon: emptyIcon!,
            )
          else
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TaskCard(
                  key: ValueKey('task-card-${task.id}'),
                  task: task,
                  onChanged: (isCompleted) => onTaskChanged(task, isCompleted),
                  onEdit: () => onEditTask(task),
                  onDelete: () => onDeleteTask(task),
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({
    required this.message,
    required this.support,
    required this.icon,
  });

  final String message;
  final String support;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    support,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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

class _EmptyTaskList extends StatelessWidget {
  const _EmptyTaskList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.task_alt_rounded, size: 40, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Nenhuma tarefa cadastrada.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Use o botão Nova tarefa para começar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma tarefa encontrada.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Tente alterar a busca ou limpar os filtros.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Limpar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}
