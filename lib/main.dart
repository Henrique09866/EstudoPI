import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'services/notification_service.dart';
import 'services/app_settings_controller.dart';
import 'services/app_settings_storage_service.dart';
import 'services/app_shortcut_controller.dart';
import 'services/account_sync_controller.dart';
import 'services/study_session_storage_service.dart';
import 'services/task_storage_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final shortcutController = AppShortcutController();
  const shortcutChannel = MethodChannel('curujao/shortcuts');
  shortcutChannel.setMethodCallHandler((call) async {
    if (call.method == 'startPomodoro') {
      shortcutController.handleAction(call.arguments as String?);
    }
  });
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
  try {
    await NotificationService.instance.reconcileStudyRevisionReminders(
      await StudySessionStorageService.instance().getRevisions(),
    );
  } catch (_) {
    // Os lembretes de revisão são opcionais e não impedem a abertura do app.
  }

  try {
    shortcutController.handleAction(
      await shortcutChannel.invokeMethod<String>('getLaunchAction'),
    );
  } on PlatformException {
    // O atalho é uma melhoria exclusiva do Android.
  } on MissingPluginException {
    // A implementação nativa não existe em desktop e testes.
  }

  final taskStorage = TaskStorageService.instance();
  final studyStorage = StudySessionStorageService.instance();
  late final AccountSyncController accountController;
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    accountController = AccountSyncController.firebase(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      taskStorage: taskStorage,
      studyStorage: studyStorage,
      settingsController: settingsController,
    );
  } catch (_) {
    accountController = AccountSyncController.unavailable(
      taskStorage: taskStorage,
      studyStorage: studyStorage,
      settingsController: settingsController,
      unavailableReason:
          'Conecte este aplicativo ao projeto Firebase para liberar a conta e a sincronização.',
    );
  }
  await accountController.initialize();

  runApp(
    EstudoPiApp(
      settingsController: settingsController,
      shortcutController: shortcutController,
      accountController: accountController,
    ),
  );
}
