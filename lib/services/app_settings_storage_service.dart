import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import 'app_settings_storage.dart';

class AppSettingsStorageService implements AppSettingsStorage {
  AppSettingsStorageService(this._box);

  static const String boxName = 'settings';
  static const String _settingsKey = 'appSettings';

  final Box<dynamic> _box;

  static Future<void> init() async {
    await Hive.openBox<dynamic>(boxName);
  }

  factory AppSettingsStorageService.instance() {
    return AppSettingsStorageService(Hive.box<dynamic>(boxName));
  }

  @override
  Future<AppSettings> load() async {
    final value = _box.get(_settingsKey);
    if (value is Map) return AppSettings.fromMap(value);
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) =>
      _box.put(_settingsKey, settings.toMap());
}
