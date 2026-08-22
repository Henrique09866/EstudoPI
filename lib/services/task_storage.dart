import '../models/task.dart';

abstract class TaskStorage {
  Future<List<Task>> getTasks();

  Future<void> saveTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(String id);
}
