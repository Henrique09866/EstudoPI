import 'package:flutter/material.dart';

import '../models/task.dart';

enum TaskStatusFilter { all, pending, completed, overdue }

extension TaskStatusFilterLabel on TaskStatusFilter {
  String get label {
    return switch (this) {
      TaskStatusFilter.all => 'Todas',
      TaskStatusFilter.pending => 'Pendentes',
      TaskStatusFilter.completed => 'Concluídas',
      TaskStatusFilter.overdue => 'Atrasadas',
    };
  }
}

class TaskFilters {
  const TaskFilters({
    this.status = TaskStatusFilter.all,
    this.priority,
    this.category,
    this.subject,
  });

  final TaskStatusFilter status;
  final TaskPriority? priority;
  final TaskCategory? category;
  final String? subject;

  bool get isActive => activeCount > 0;

  int get activeCount =>
      (status == TaskStatusFilter.all ? 0 : 1) +
      (priority == null ? 0 : 1) +
      (category == null ? 0 : 1) +
      (subject == null ? 0 : 1);

  TaskFilters copyWith({
    TaskStatusFilter? status,
    TaskPriority? priority,
    TaskCategory? category,
    Object? subject = _filterSentinel,
  }) {
    return TaskFilters(
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      subject: identical(subject, _filterSentinel)
          ? this.subject
          : subject as String?,
    );
  }
}

const _filterSentinel = Object();

class TaskFilterSheet extends StatefulWidget {
  const TaskFilterSheet({
    super.key,
    required this.initialFilters,
    required this.subjects,
  });

  final TaskFilters initialFilters;
  final List<String> subjects;

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  late TaskStatusFilter _status;
  late TaskPriority? _priority;
  late TaskCategory? _category;
  late String? _subject;

  @override
  void initState() {
    super.initState();
    _status = widget.initialFilters.status;
    _priority = widget.initialFilters.priority;
    _category = widget.initialFilters.category;
    _subject = widget.initialFilters.subject;
  }

  void _clear() {
    setState(() {
      _status = TaskStatusFilter.all;
      _priority = null;
      _category = null;
      _subject = null;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      TaskFilters(
        status: _status,
        priority: _priority,
        category: _category,
        subject: _subject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('clear-filters-button'),
                    onPressed: _clear,
                    child: const Text('Limpar filtros'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<TaskStatusFilter>(
                key: const ValueKey('filter-status-field'),
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                items: TaskStatusFilter.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (status) {
                  if (status != null) setState(() => _status = status);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<TaskPriority?>(
                key: const ValueKey('filter-priority-field'),
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Prioridade',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: [
                  const DropdownMenuItem<TaskPriority?>(
                    value: null,
                    child: Text('Todas'),
                  ),
                  ...TaskPriority.values.map(
                    (priority) => DropdownMenuItem<TaskPriority?>(
                      value: priority,
                      child: Text(_priorityLabel(priority)),
                    ),
                  ),
                ],
                onChanged: (priority) => setState(() => _priority = priority),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<TaskCategory?>(
                key: const ValueKey('filter-category-field'),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<TaskCategory?>(
                    value: null,
                    child: Text('Todas'),
                  ),
                  ...TaskCategory.values.map(
                    (category) => DropdownMenuItem<TaskCategory?>(
                      value: category,
                      child: Text(category.label),
                    ),
                  ),
                ],
                onChanged: (category) => setState(() => _category = category),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                key: const ValueKey('filter-subject-field'),
                initialValue: _subject,
                decoration: const InputDecoration(
                  labelText: 'Matéria',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas'),
                  ),
                  ...widget.subjects.map(
                    (subject) => DropdownMenuItem<String?>(
                      value: subject,
                      child: Text(subject, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (subject) => setState(() => _subject = subject),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('apply-filters-button'),
                onPressed: _apply,
                child: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _priorityLabel(TaskPriority priority) {
  return switch (priority) {
    TaskPriority.low => 'Baixa',
    TaskPriority.medium => 'Média',
    TaskPriority.high => 'Alta',
  };
}
