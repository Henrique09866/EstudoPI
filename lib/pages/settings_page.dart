import 'package:flutter/material.dart';

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

  Future<void> _selectTime() async {
    final settings = widget.controller.settings;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.dailyReminderHour,
        minute: settings.dailyReminderMinute,
      ),
    );
    if (selected != null) {
      await widget.controller.setDailyReminderTime(selected);
    }
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
                const SizedBox(height: 28),
                _SectionLabel('LEMBRETES'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('settings-daily-reminder'),
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Lembrete diário'),
                        value: settings.dailyReminderEnabled,
                        onChanged: widget.controller.setDailyReminderEnabled,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('settings-reminder-time'),
                        enabled: settings.dailyReminderEnabled,
                        leading: const Icon(Icons.schedule_outlined),
                        title: const Text('Horário'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _timeLabel(
                                settings.dailyReminderHour,
                                settings.dailyReminderMinute,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: _selectTime,
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

  static String _timeLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
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
