import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import 'task_storage.dart';

class TaskStorageService implements TaskStorage {
  TaskStorageService(this._box);

  static const String boxName = 'tasks';

  final Box<dynamic> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(boxName);
  }

  factory TaskStorageService.instance() {
    return TaskStorageService(Hive.box<dynamic>(boxName));
  }

  @override
  Future<List<Task>> getTasks() async {
    final tasks = <Task>[];

    for (final value in _box.values.whereType<Map>()) {
      try {
        tasks.add(Task.fromMap(Map<String, dynamic>.from(value)));
      } catch (_) {
        continue;
      }
    }

    return tasks;
  }

  @override
  Future<void> saveTask(Task task) async {
    await _box.put(task.id, task.toMap());
  }

  @override
  Future<void> updateTask(Task task) async {
    await saveTask(task);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }
}
