import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../services/app_settings_controller.dart';
import 'theme/app_theme.dart';

class EstudoPiApp extends StatefulWidget {
  const EstudoPiApp({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  State<EstudoPiApp> createState() => _EstudoPiAppState();
}

class _EstudoPiAppState extends State<EstudoPiApp> {
  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estudo Pi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: widget.settingsController.themeMode,
      home: HomePage(settingsController: widget.settingsController),
    );
  }
}
