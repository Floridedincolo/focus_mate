import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/task_repository.dart';
import '../../models/task.dart';
import '../../services/firestore_service.dart';

class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({FirestoreService? service})
      : _service = service ?? FirestoreService();

  final FirestoreService _service;

  @override
  Stream<List<Task>> watchTasks() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_service.userId)
        .collection('tasks')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return Task.fromMap(data);
          }).toList(),
        );
  }

  @override
  Future<void> saveTask(Task task) => _service.saveTask(task);

  @override
  Future<void> deleteTask(String taskId) => _service.deleteTask(taskId);

  @override
  Future<int> markTaskStatus(Task task, DateTime date, String status) =>
      _service.markTaskStatus(task, date, status);

  @override
  Future<int> clearCompletion(Task task, DateTime date) =>
      _service.clearCompletion(task, date);

  @override
  Future<String> getCompletionStatus(Task task, DateTime date) =>
      _service.getCompletionStatus(task, date);
}
