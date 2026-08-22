import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/notification_service.dart';
import 'services/app_settings_controller.dart';
import 'services/app_settings_storage_service.dart';
import 'services/study_session_storage_service.dart';
import 'services/task_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TaskStorageService.init();
  await StudySessionStorageService.init();
  await AppSettingsStorageService.init();
  await NotificationService.init();

  final settingsController = AppSettingsController(
    AppSettingsStorageService.instance(),
    NotificationService.instance,
  );
  await settingsController.load();
  await settingsController.reconcileDailyReminder();

  runApp(EstudoPiApp(settingsController: settingsController));
}
