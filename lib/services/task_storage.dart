import '../models/task.dart';

abstract class TaskStorage {
  Future<List<Task>> getTasks();

  Future<void> saveTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(String id);

  /// Substitui a lista local por uma cópia completa recebida da nuvem.
  Future<void> replaceAllTasks(List<Task> tasks) async {
    for (final task in await getTasks()) {
      await deleteTask(task.id);
    }
    for (final task in tasks) {
      await saveTask(task);
    }
  }
}
