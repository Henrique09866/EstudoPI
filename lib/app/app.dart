import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/account_page.dart';
import '../services/app_settings_controller.dart';
import '../services/app_shortcut_controller.dart';
import '../services/account_sync_controller.dart';
import 'theme/app_theme.dart';

class EstudoPiApp extends StatefulWidget {
  const EstudoPiApp({
    super.key,
    required this.settingsController,
    this.shortcutController,
    this.accountController,
  });

  final AppSettingsController settingsController;
  final AppShortcutController? shortcutController;
  final AccountSyncController? accountController;

  @override
  State<EstudoPiApp> createState() => _EstudoPiAppState();
}

class _EstudoPiAppState extends State<EstudoPiApp> {
  Timer? _nightModeTimer;

  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_onSettingsChanged);
    widget.accountController?.addListener(_onAccountChanged);
    _nightModeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _onSettingsChanged(),
    );
  }

  @override
  void dispose() {
    _nightModeTimer?.cancel();
    widget.settingsController.removeListener(_onSettingsChanged);
    widget.accountController?.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  void _onAccountChanged() {
    if (mounted) setState(() {});
  }

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
    final account = widget.accountController;
    final shouldShowAccount =
        account != null && account.isAvailable && !account.isSignedIn;

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
      home: shouldShowAccount
          ? AccountPage(controller: account)
          : HomePage(
              settingsController: widget.settingsController,
              shortcutController: widget.shortcutController,
              accountController: widget.accountController,
            ),
    );
  }
}
