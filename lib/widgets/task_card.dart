import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
    this.onReschedule,
  });

  final Task task;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final priorityStyle = task.priority.style(context);
    final isOverdue = task.isOverdue;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: task.isCompleted ? 0.72 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (value) => onChanged(value ?? false),
                semanticLabel: task.isCompleted
                    ? 'Marcar ${task.title} como pendente'
                    : 'Marcar ${task.title} como concluída',
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (task.description != null &&
                        task.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (task.subject != null &&
                        task.subject!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        task.subject!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _TaskBadge(
                          icon: Icons.schedule_outlined,
                          label: _formatTime(task.dateTime),
                          color: colorScheme.primary,
                        ),
                        _TaskBadge(
                          icon: priorityStyle.icon,
                          label: priorityStyle.label,
                          color: priorityStyle.color,
                        ),
                        _TaskBadge(
                          icon: Icons.category_outlined,
                          label: task.category.label,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        if (task.recurrence != TaskRecurrence.none)
                          _TaskBadge(
                            icon: Icons.repeat_rounded,
                            label: _recurrenceLabel(task),
                            color: colorScheme.primary,
                          ),
                        if (isOverdue)
                          _TaskBadge(
                            icon: Icons.error_outline_rounded,
                            label: 'Atrasada',
                            color: colorScheme.error,
                          )
                        else
                          _TaskBadge(
                            icon: task.isCompleted
                                ? Icons.task_alt_rounded
                                : Icons.pending_actions_outlined,
                            label: task.isCompleted ? 'Concluída' : 'Pendente',
                            color: task.isCompleted
                                ? colorScheme.tertiary
                                : colorScheme.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_TaskAction>(
                key: ValueKey('task-actions-${task.id}'),
                tooltip: 'Ações da tarefa',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (action) {
                  if (action == _TaskAction.edit) {
                    onEdit();
                    return;
                  }
                  if (action == _TaskAction.reschedule) {
                    onReschedule?.call();
                    return;
                  }
                  onDelete();
                },
                itemBuilder: (context) => [
                  if (isOverdue && onReschedule != null)
                    const PopupMenuItem(
                      value: _TaskAction.reschedule,
                      child: ListTile(
                        leading: Icon(Icons.event_repeat_outlined),
                        title: Text('Reagendar para amanhã'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: _TaskAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _TaskAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Excluir'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _recurrenceLabel(Task task) {
    if (task.recurrence != TaskRecurrence.customWeekdays) {
      return task.recurrence.label;
    }

    return task.recurrenceWeekdays.map(weekdayShortLabel).join(', ');
  }
}

enum _TaskAction { reschedule, edit, delete }

class _TaskBadge extends StatelessWidget {
  const _TaskBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension TaskPriorityStyle on TaskPriority {
  String get label {
    return switch (this) {
      TaskPriority.low => 'Baixa',
      TaskPriority.medium => 'Média',
      TaskPriority.high => 'Alta',
    };
  }

  PriorityStyle style(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (this) {
      TaskPriority.low => PriorityStyle(
        label: label,
        icon: Icons.low_priority,
        color: colorScheme.secondary,
      ),
      TaskPriority.medium => PriorityStyle(
        label: label,
        icon: Icons.drag_handle_rounded,
        color: colorScheme.primary,
      ),
      TaskPriority.high => PriorityStyle(
        label: label,
        icon: Icons.priority_high_rounded,
        color: colorScheme.error,
      ),
    };
  }
}

class PriorityStyle {
  const PriorityStyle({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
