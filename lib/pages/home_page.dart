import 'dart:async';

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
import '../services/home_insights_service.dart';
import '../services/app_settings_controller.dart';
import '../services/app_shortcut_controller.dart';
import '../services/account_sync_controller.dart';
import '../services/android_study_widget_service.dart';
import '../widgets/task_card.dart';
import '../widgets/task_filter_sheet.dart';
import 'calendar_page.dart';
import 'progress_page.dart';
import 'study_page.dart';
import 'settings_page.dart';
import 'account_page.dart';
import 'task_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialTasks,
    this.storage,
    this.notifications,
    this.studyStorage,
    this.settingsController,
    this.shortcutController,
    this.accountController,
  });

  final List<Task>? initialTasks;
  final TaskStorage? storage;
  final TaskNotificationScheduler? notifications;
  final StudySessionStorage? studyStorage;
  final AppSettingsController? settingsController;
  final AppShortcutController? shortcutController;
  final AccountSyncController? accountController;

  static const double _desktopMaxWidth = 1180;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TaskStorage _storage;
  late final TaskNotificationScheduler _notifications;
  late final StudySessionStorage? _studyStorage;
  final _searchController = TextEditingController();
  final _recurrenceService = TaskRecurrenceService();
  final _insightsService = const HomeInsightsService();
  final _changingTaskIds = <String>{};
  late List<Task> _tasks;
  // Tarefas concluídas continuam salvas e podem ser consultadas pelo filtro,
  // mas não aparecem na lista principal como se fossem uma cópia da tarefa.
  var _filters = const TaskFilters();
  var _isLoading = true;
  var _searchQuery = '';
  var _studyMinutesToday = 0;
  List<StudySession> _sessions = const [];
  var _dailyStudyGoalMinutes =
      StudySessionStorageService.defaultDailyGoalMinutes;
  var _seenCloudDataVersion = 0;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? TaskStorageService.instance();
    _notifications = widget.notifications ?? NotificationService.instance;
    _studyStorage = widget.studyStorage ?? _availableStudyStorage();
    _tasks = List.of(widget.initialTasks ?? const []);
    widget.settingsController?.addListener(_onSettingsChanged);
    widget.shortcutController?.addListener(_onShortcutRequested);
    widget.accountController?.addListener(_onAccountChanged);
    _seenCloudDataVersion = widget.accountController?.dataVersion ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShortcutRequested());

    if (widget.initialTasks != null) {
      _isLoading = false;
      _loadStudySummary();
      return;
    }

    _loadTasks();
    _loadStudySummary();
  }

  @override
  void dispose() {
    widget.settingsController?.removeListener(_onSettingsChanged);
    widget.shortcutController?.removeListener(_onShortcutRequested);
    widget.accountController?.removeListener(_onAccountChanged);
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
      unawaited(_scheduleDailyStudySummary());
      unawaited(_updateAndroidWidget());
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
        _sessions = results[0] as List<StudySession>;
        _studyMinutesToday = duration.inMinutes;
        _dailyStudyGoalMinutes = results[1] as int;
      });
      unawaited(_scheduleDailyStudySummary());
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
      unawaited(_updateAndroidWidget());
      unawaited(_syncAccount());
      unawaited(_scheduleDailyStudySummary());
      if (!updatedTask.isCompleted) return;

      final nextTask = _recurrenceService.createNextOccurrence(updatedTask);
      if (nextTask == null) return;

      try {
        await _storage.saveTask(nextTask);
        await _scheduleNotification(nextTask);
        if (!mounted) return;
        setState(() => _tasks = [..._tasks, nextTask]);
        unawaited(_updateAndroidWidget());
        unawaited(_syncAccount());
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
      unawaited(_updateAndroidWidget());
      unawaited(_syncAccount());
      unawaited(_scheduleDailyStudySummary());
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
      unawaited(_updateAndroidWidget());
      unawaited(_syncAccount());
      unawaited(_scheduleDailyStudySummary());
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
      unawaited(_updateAndroidWidget());
      unawaited(_syncAccount());
      unawaited(_scheduleDailyStudySummary());
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
    if (mounted) {
      await _loadTasks();
      unawaited(_syncAccount());
    }
  }

  Future<void> _openStudy({bool autoStartPomodoro = false}) async {
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
        builder: (context) => StudyPage(
          storage: _studyStorage,
          timerAlarms: NotificationService.instance,
          timerStatusNotifier: NotificationService.instance,
          revisionReminders: NotificationService.instance,
          autoStartPomodoro: autoStartPomodoro,
          settings: widget.settingsController?.settings,
          subjects: subjects,
        ),
      ),
    );
    if (mounted) {
      await _loadStudySummary();
      unawaited(_syncAccount());
    }
  }

  Future<void> _openProgress() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProgressPage(tasks: List.of(_tasks), storage: _studyStorage),
      ),
    );
    if (mounted) unawaited(_syncAccount());
  }

  Future<void> _openSettings() async {
    final controller = widget.settingsController;
    if (controller == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          controller: controller,
          taskStorage: _storage,
          studyStorage: _studyStorage,
          accountController: widget.accountController,
        ),
      ),
    );
    if (mounted) unawaited(_syncAccount());
  }

  Future<void> _openAccount() async {
    final controller = widget.accountController;
    if (controller == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => AccountPage(controller: controller)),
    );
    if (mounted) unawaited(_syncAccount());
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filters = const TaskFilters();
    });
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
    widget.accountController?.syncAfterLocalChange();
  }

  void _onAccountChanged() {
    final controller = widget.accountController;
    if (controller == null) return;
    if (controller.dataVersion != _seenCloudDataVersion) {
      _seenCloudDataVersion = controller.dataVersion;
      unawaited(_reloadDataAfterCloudUpdate());
    }
    if (mounted) setState(() {});
  }

  Future<void> _reloadDataAfterCloudUpdate() async {
    await _loadTasks();
    await _loadStudySummary();
  }

  Future<void> _syncAccount() async {
    widget.accountController?.syncAfterLocalChange();
  }

  void _onShortcutRequested() {
    final shortcutController = widget.shortcutController;
    if (shortcutController == null ||
        !shortcutController.consumeStartPomodoroRequest()) {
      return;
    }
    unawaited(_openStudy(autoStartPomodoro: true));
  }

  Future<void> _rescheduleOverdueTask(Task task) async {
    if (!task.isOverdue || _changingTaskIds.contains(task.id)) return;
    _changingTaskIds.add(task.id);
    final now = DateTime.now();
    final rescheduled = task.copyWith(
      dateTime: DateTime(
        now.year,
        now.month,
        now.day + 1,
        task.dateTime.hour,
        task.dateTime.minute,
      ),
    );
    try {
      await _cancelNotification(task.id);
      await _storage.updateTask(rescheduled);
      await _scheduleNotification(rescheduled);
      if (!mounted) return;
      setState(() {
        _tasks = [
          for (final current in _tasks)
            if (current.id == task.id) rescheduled else current,
        ];
      });
      unawaited(_updateAndroidWidget());
      unawaited(_syncAccount());
      unawaited(_scheduleDailyStudySummary());
      _showNotificationMessage('Tarefa reagendada para amanhã.');
    } catch (_) {
      _showStorageError('Não foi possível reagendar a tarefa.');
    } finally {
      _changingTaskIds.remove(task.id);
    }
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

  Future<void> _scheduleDailyStudySummary() async {
    try {
      final now = DateTime.now();
      final completedTasks = _tasks
          .where((task) => task.isCompleted && _isSameDay(task.dateTime, now))
          .length;
      final pendingTasks = _tasks
          .where((task) => task.isPending && _isSameDay(task.dateTime, now))
          .length;
      await NotificationService.instance.scheduleDailyStudySummary(
        completedTasks: completedTasks,
        pendingTasks: pendingTasks,
        studyMinutes: _studyMinutesToday,
      );
    } catch (_) {
      // O resumo é complementar e não pode interromper a tela inicial.
    }
  }

  Future<void> _updateAndroidWidget() async {
    final pending = _tasks.where((task) => task.isPending).toList()
      ..sort((first, second) => first.dateTime.compareTo(second.dateTime));
    await AndroidStudyWidgetService.updateNextTask(
      pending.isEmpty ? null : pending.first,
    );
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
    final streak = _insightsService.studyStreak(_sessions, now: now);
    final weeklySummary = _insightsService.weeklySummary(
      sessions: _sessions,
      tasks: _tasks,
      now: now,
    );
    final todayPlan = _insightsService.planToday(_tasks, now: now);
    final settings = widget.settingsController?.settings;

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
                      showCompletedTasks:
                          _filters.status == TaskStatusFilter.completed,
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
                      onOpenAccount: widget.accountController == null
                          ? null
                          : _openAccount,
                      onOpenSettings: _openSettings,
                      studyMinutesToday: _studyMinutesToday,
                      dailyStudyGoalMinutes: _dailyStudyGoalMinutes,
                      showInsights: widget.settingsController != null,
                      streak: streak,
                      weeklySummary: weeklySummary,
                      todayPlan: todayPlan,
                      countdownTitle: settings?.countdownTitle,
                      countdownDate: settings?.countdownDate,
                      onClearFilters: _clearFilters,
                      onTaskChanged: _toggleTaskCompletion,
                      onEditTask: _editTask,
                      onDeleteTask: _confirmDeleteTask,
                      onRescheduleTask: _rescheduleOverdueTask,
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
    required this.showCompletedTasks,
    required this.todayPendingCount,
    required this.overdueCount,
    required this.searchController,
    required this.filters,
    required this.onSearchChanged,
    required this.onOpenFilters,
    required this.onOpenCalendar,
    required this.onOpenStudy,
    required this.onOpenProgress,
    required this.onOpenAccount,
    required this.onOpenSettings,
    required this.studyMinutesToday,
    required this.dailyStudyGoalMinutes,
    required this.showInsights,
    required this.streak,
    required this.weeklySummary,
    required this.todayPlan,
    required this.countdownTitle,
    required this.countdownDate,
    required this.onClearFilters,
    required this.onTaskChanged,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onRescheduleTask,
  });

  final bool allTasksAreEmpty;
  final bool noResults;
  final List<Task> overdueTasks;
  final List<Task> todayTasks;
  final List<Task> upcomingTasks;
  final List<Task> completedTasks;
  final List<Task> completedToday;
  final bool showCompletedTasks;
  final int todayPendingCount;
  final int overdueCount;
  final TextEditingController searchController;
  final TaskFilters filters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenProgress;
  final VoidCallback? onOpenAccount;
  final VoidCallback onOpenSettings;
  final int studyMinutesToday;
  final int dailyStudyGoalMinutes;
  final bool showInsights;
  final int streak;
  final WeeklyStudySummary weeklySummary;
  final List<Task> todayPlan;
  final String? countdownTitle;
  final DateTime? countdownDate;
  final VoidCallback onClearFilters;
  final void Function(Task task, bool isCompleted) onTaskChanged;
  final ValueChanged<Task> onEditTask;
  final ValueChanged<Task> onDeleteTask;
  final ValueChanged<Task> onRescheduleTask;

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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  semanticLabel: 'Logo do Curujão Estudos',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Curujão Estudos',
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
            if (onOpenAccount != null)
              IconButton(
                key: const ValueKey('open-account-button'),
                tooltip: 'Abrir conta e login',
                onPressed: onOpenAccount,
                icon: const Icon(Icons.account_circle_outlined),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final summary = _TodaySummary(
              pendingCount: todayPendingCount,
              completedCount: completedToday.length,
              overdueCount: overdueCount,
              totalCount: totalToday,
            );
            final studyRhythm = _StudyRhythmCard(
              streak: streak,
              summary: weeklySummary,
              countdownTitle: countdownTitle,
              countdownDate: countdownDate,
              studyMinutesToday: studyMinutesToday,
              dailyStudyGoalMinutes: dailyStudyGoalMinutes,
              onOpenStudy: onOpenStudy,
            );
            if (constraints.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  if (showInsights) ...[
                    const SizedBox(height: 16),
                    _TodayPlanCard(tasks: todayPlan),
                  ],
                  const SizedBox(height: 12),
                  studyRhythm,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      if (showInsights) ...[
                        const SizedBox(height: 16),
                        _TodayPlanCard(tasks: todayPlan),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: studyRhythm),
              ],
            );
          },
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
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final overdue = _TaskSection(
                title: 'Atrasadas',
                count: overdueTasks.length,
                tasks: overdueTasks,
                onTaskChanged: onTaskChanged,
                onEditTask: onEditTask,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
              );
              final today = _TaskSection(
                title: 'Hoje',
                count: todayTasks.length,
                emptyMessage: 'Nenhuma tarefa para hoje',
                emptySupport: 'Você está em dia 🎉',
                emptyIcon: Icons.wb_sunny_outlined,
                tasks: todayTasks,
                onTaskChanged: onTaskChanged,
                onEditTask: onEditTask,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
              );
              final upcoming = _TaskSection(
                title: 'Próximas',
                count: upcomingTasks.length,
                emptyMessage: 'Nenhuma tarefa futura',
                emptySupport: 'Planeje sua próxima sessão quando precisar.',
                emptyIcon: Icons.event_available_outlined,
                tasks: upcomingTasks,
                onTaskChanged: onTaskChanged,
                onEditTask: onEditTask,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
              );
              final completed = _TaskSection(
                title: 'Concluídas',
                count: completedTasks.length,
                emptyMessage: 'Nenhuma tarefa concluída',
                emptySupport: 'Suas conquistas aparecerão aqui.',
                emptyIcon: Icons.task_alt_rounded,
                tasks: completedTasks,
                onTaskChanged: onTaskChanged,
                onEditTask: onEditTask,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
              );
              if (constraints.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (overdueTasks.isNotEmpty) overdue,
                    today,
                    upcoming,
                    if (showCompletedTasks) completed,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [if (overdueTasks.isNotEmpty) overdue, today],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [upcoming, if (showCompletedTasks) completed],
                    ),
                  ),
                ],
              );
            },
          ),
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

class _StudyRhythmCard extends StatelessWidget {
  const _StudyRhythmCard({
    required this.streak,
    required this.summary,
    required this.countdownTitle,
    required this.countdownDate,
    required this.studyMinutesToday,
    required this.dailyStudyGoalMinutes,
    required this.onOpenStudy,
  });

  final int streak;
  final WeeklyStudySummary summary;
  final String? countdownTitle;
  final DateTime? countdownDate;
  final int studyMinutesToday;
  final int dailyStudyGoalMinutes;
  final VoidCallback onOpenStudy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final studyProgress = dailyStudyGoalMinutes == 0
        ? 0.0
        : (studyMinutesToday / dailyStudyGoalMinutes).clamp(0.0, 1.0);
    final subjects = summary.subjects.take(2).toList();
    final subjectsLabel = subjects.isEmpty
        ? 'Nenhuma matéria registrada nesta semana.'
        : subjects
              .map(
                (subject) =>
                    '${subject.subject} (${_formatStudyDuration(subject.duration)})',
              )
              .join(' · ');
    final countdownLabel = _countdownLabel(countdownDate);

    return Card(
      child: ExpansionTile(
        key: const ValueKey('study-rhythm-card'),
        leading: Icon(Icons.nights_stay_outlined, color: colorScheme.primary),
        title: Text(
          'Seu ritmo',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text('Sequência, semana e meta de estudo'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              key: const ValueKey('start-study-from-home-button'),
              onPressed: onOpenStudy,
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: const Text('Estudar'),
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          _RhythmDetail(
            icon: Icons.local_fire_department_outlined,
            label: 'Sequência',
            value: streak == 0
                ? 'Estude hoje para iniciar.'
                : streak == 1
                ? '1 noite seguida'
                : '$streak noites seguidas',
            color: colorScheme.tertiary,
          ),
          const SizedBox(height: 14),
          _RhythmDetail(
            icon: Icons.date_range_outlined,
            label: 'Últimos 7 dias',
            value:
                '${_formatStudyDuration(summary.duration)} estudados\n$subjectsLabel',
          ),
          const SizedBox(height: 14),
          _RhythmDetail(
            icon: summary.overdueTasks == 0
                ? Icons.task_alt_outlined
                : Icons.warning_amber_rounded,
            label: 'Tarefas atrasadas',
            value: '${summary.overdueTasks}',
            color: summary.overdueTasks == 0
                ? colorScheme.tertiary
                : colorScheme.error,
          ),
          if (countdownDate != null) ...[
            const SizedBox(height: 14),
            _RhythmDetail(
              icon: Icons.flag_outlined,
              label: countdownTitle ?? 'Minha prova',
              value: countdownLabel,
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Área de estudos',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text('$studyMinutesToday min / $dailyStudyGoalMinutes min hoje'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: studyProgress, minHeight: 6),
        ],
      ),
    );
  }

  static String _countdownLabel(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final days = target.difference(today).inDays;
    if (days < 0) return 'A data já passou';
    if (days == 0) return 'É hoje!';
    return days == 1 ? 'Falta 1 dia' : 'Faltam $days dias';
  }
}

class _RhythmDetail extends StatelessWidget {
  const _RhythmDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planejar hoje',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            tasks.isEmpty
                ? 'Você não tem tarefas pendentes para priorizar.'
                : 'Estas são as 3 tarefas mais importantes agora.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var index = 0; index < tasks.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    CircleAvatar(radius: 12, child: Text('${index + 1}')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tasks[index].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      tasks[index].priority.style(context).icon,
                      size: 18,
                      color: tasks[index].priority.style(context).color,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

String _formatStudyDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}min';
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
    required this.onRescheduleTask,
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
  final ValueChanged<Task> onRescheduleTask;
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
                  onReschedule: task.isOverdue
                      ? () => onRescheduleTask(task)
                      : null,
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
