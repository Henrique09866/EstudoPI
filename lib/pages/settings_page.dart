import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/app_settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final AppSettingsController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _selectTheme() async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values
              .map(
                (mode) => ListTile(
                  leading: Icon(
                    mode == widget.controller.themeMode
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: mode == widget.controller.themeMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(_themeLabel(mode)),
                  onTap: () => Navigator.pop(context, mode),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await widget.controller.setThemeMode(selected);
    }
  }

  Future<void> _addReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null) return;
    await widget.controller.setDailyReminderTimes([
      ...widget.controller.settings.dailyReminderTimes,
      DailyReminderTime(hour: time.hour, minute: time.minute),
    ]);
  }

  Future<void> _editCountdown() async {
    final settings = widget.controller.settings;
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: settings.countdownDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );
    if (selectedDate == null || !mounted) return;
    final titleController = TextEditingController(
      text: settings.countdownTitle ?? '',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome da contagem'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Prova, ENEM ou concurso',
            hintText: 'Ex.: ENEM 2027',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, titleController.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    titleController.dispose();
    if (title == null) return;
    await widget.controller.setCountdown(
      title: title.isEmpty ? 'Minha prova' : title,
      date: selectedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _SectionLabel('APARÊNCIA'),
                Card(
                  child: ListTile(
                    key: const ValueKey('settings-theme'),
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Tema'),
                    subtitle: Text(_themeLabel(settings.themeMode)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _selectTheme,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('settings-night-mode'),
                        secondary: const Icon(Icons.nightlight_round),
                        title: const Text('Modo Corujão'),
                        subtitle: const Text(
                          'Usar tema escuro automaticamente das 18h às 6h.',
                        ),
                        value: settings.nightModeEnabled,
                        onChanged: widget.controller.setNightModeEnabled,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const ValueKey('settings-reduce-brightness'),
                        secondary: const Icon(Icons.brightness_4_outlined),
                        title: const Text('Reduzir brilho à noite'),
                        subtitle: const Text(
                          'Escurece um pouco mais as superfícies do tema noturno.',
                        ),
                        value: settings.reduceBrightness,
                        onChanged: widget.controller.setReduceBrightness,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SectionLabel('POMODORO'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PomodoroMinutes(
                          label: 'Tempo de foco',
                          selected: settings.pomodoroFocusMinutes,
                          options: const [15, 20, 25, 30, 45, 50, 60],
                          onSelected: (minutes) => widget.controller
                              .setPomodoroSettings(focusMinutes: minutes),
                        ),
                        const SizedBox(height: 16),
                        _PomodoroMinutes(
                          label: 'Pausa curta',
                          selected: settings.pomodoroShortBreakMinutes,
                          options: const [3, 5, 10, 15],
                          onSelected: (minutes) => widget.controller
                              .setPomodoroSettings(shortBreakMinutes: minutes),
                        ),
                        const SizedBox(height: 16),
                        _PomodoroMinutes(
                          label: 'Pausa longa (a cada 4 focos)',
                          selected: settings.pomodoroLongBreakMinutes,
                          options: const [10, 15, 20, 30],
                          onSelected: (minutes) => widget.controller
                              .setPomodoroSettings(longBreakMinutes: minutes),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Iniciar pausa automaticamente'),
                          value: settings.pomodoroAutoStartBreak,
                          onChanged: (value) => widget.controller
                              .setPomodoroSettings(autoStartBreak: value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Som ao terminar'),
                          value: settings.pomodoroSoundEnabled,
                          onChanged: (value) => widget.controller
                              .setPomodoroSettings(soundEnabled: value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Vibrar ao terminar'),
                          value: settings.pomodoroVibrationEnabled,
                          onChanged: (value) => widget.controller
                              .setPomodoroSettings(vibrationEnabled: value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _SectionLabel('ALARMES'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('settings-daily-reminder'),
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Alarme diário'),
                        subtitle: Text(
                          settings.dailyReminderEnabled
                              ? 'Todos os dias às ${_reminderTimesLabel(settings.dailyReminderTimes)}'
                              : 'Desativado',
                        ),
                        value: settings.dailyReminderEnabled,
                        onChanged: widget.controller.setDailyReminderEnabled,
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Horários dos lembretes',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Escolha um ou mais horários para planejar o dia.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final time in settings.dailyReminderTimes)
                                  InputChip(
                                    key: ValueKey(
                                      'settings-reminder-${time.hour}-${time.minute}',
                                    ),
                                    label: Text(time.label),
                                    onDeleted:
                                        settings.dailyReminderEnabled &&
                                            settings.dailyReminderTimes.length >
                                                1
                                        ? () => widget.controller
                                              .setDailyReminderTimes(
                                                settings.dailyReminderTimes
                                                    .where(
                                                      (item) => item != time,
                                                    )
                                                    .toList(),
                                              )
                                        : null,
                                  ),
                                ActionChip(
                                  key: const ValueKey(
                                    'settings-add-reminder-time',
                                  ),
                                  avatar: const Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Horário'),
                                  onPressed: settings.dailyReminderEnabled
                                      ? _addReminderTime
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Dias dos lembretes',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(7, (index) {
                                final weekday = index + 1;
                                final selected = settings.dailyReminderWeekdays
                                    .contains(weekday);
                                final onlySelected =
                                    selected &&
                                    settings.dailyReminderWeekdays.length == 1;
                                return FilterChip(
                                  label: Text(_weekdayLabel(weekday)),
                                  selected: selected,
                                  onSelected:
                                      settings.dailyReminderEnabled &&
                                          !onlySelected
                                      ? (_) => widget.controller
                                            .toggleDailyReminderWeekday(weekday)
                                      : null,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.controller.dailyReminderAvailable) ...[
                  const SizedBox(height: 10),
                  Text(
                    'O agendamento diário não é suportado nesta plataforma.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'No Android, permita notificações e alarmes para receber o aviso no horário escolhido.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                _SectionLabel('ACESSIBILIDADE'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tamanho do texto',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              const [
                                    (label: 'Pequeno', value: .9),
                                    (label: 'Padrão', value: 1.0),
                                    (label: 'Grande', value: 1.15),
                                    (label: 'Muito grande', value: 1.3),
                                  ]
                                  .map(
                                    (option) => ChoiceChip(
                                      label: Text(option.label),
                                      selected:
                                          settings.textScaleFactor ==
                                          option.value,
                                      onSelected: (_) => widget.controller
                                          .setTextScaleFactor(option.value),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Alto contraste'),
                          value: settings.highContrast,
                          onChanged: widget.controller.setHighContrast,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Reduzir animações'),
                          value: settings.reduceMotion,
                          onChanged: widget.controller.setReduceMotion,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _SectionLabel('CONTAGEM REGRESSIVA'),
                Card(
                  child: ListTile(
                    key: const ValueKey('settings-countdown'),
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(
                      settings.countdownTitle ?? 'Prova, ENEM ou concurso',
                    ),
                    subtitle: Text(
                      settings.countdownDate == null
                          ? 'Adicione uma data importante para acompanhar no início.'
                          : 'Data marcada para ${_formatDate(settings.countdownDate!)}',
                    ),
                    trailing: settings.countdownDate == null
                        ? const Icon(Icons.chevron_right_rounded)
                        : IconButton(
                            tooltip: 'Remover contagem',
                            onPressed: widget.controller.clearCountdown,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    onTap: _editCountdown,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Escuro',
  };

  static String _reminderTimesLabel(List<DailyReminderTime> times) =>
      times.map((time) => time.label).join(', ');

  static String _weekdayLabel(int weekday) => switch (weekday) {
    DateTime.monday => 'Seg',
    DateTime.tuesday => 'Ter',
    DateTime.wednesday => 'Qua',
    DateTime.thursday => 'Qui',
    DateTime.friday => 'Sex',
    DateTime.saturday => 'Sáb',
    DateTime.sunday => 'Dom',
    _ => '',
  };

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _PomodoroMinutes extends StatelessWidget {
  const _PomodoroMinutes({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final int selected;
  final List<int> options;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (minutes) => ChoiceChip(
                label: Text('$minutes min'),
                selected: selected == minutes,
                onSelected: (_) => onSelected(minutes),
              ),
            )
            .toList(),
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}
