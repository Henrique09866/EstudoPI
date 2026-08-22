import '../models/app_settings.dart';

abstract class AppSettingsStorage {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
