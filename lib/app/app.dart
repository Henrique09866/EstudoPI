import 'dart:async';

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
  Timer? _nightModeTimer;

  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_onSettingsChanged);
    _nightModeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _onSettingsChanged(),
    );
  }

  @override
  void dispose() {
    _nightModeTimer?.cancel();
    widget.settingsController.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsController.settings;
    final hour = DateTime.now().hour;
    final isCorujaTime = hour >= 18 || hour < 6;
    final themeMode = settings.nightModeEnabled && isCorujaTime
        ? ThemeMode.dark
        : settings.themeMode;
    final lightTheme = AppTheme.withAccessibility(
      AppTheme.lightTheme,
      highContrast: settings.highContrast,
      reduceBrightness: false,
    );
    final darkTheme = AppTheme.withAccessibility(
      AppTheme.darkTheme,
      highContrast: settings.highContrast,
      reduceBrightness: settings.reduceBrightness,
    );
    return MaterialApp(
      title: 'Curujão Estudos',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(settings.textScaleFactor),
            disableAnimations: settings.reduceMotion,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomePage(settingsController: widget.settingsController),
    );
  }
}
