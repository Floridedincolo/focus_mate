import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/task_repository.dart';
import '../../models/task.dart';
import '../../services/firestore_service.dart';

/// [TaskRepository] implementation backed by Cloud Firestore.
///
/// Delegates persistence operations to [FirestoreService] so that all
/// Firestore-specific logic remains in one place.
class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({
    FirestoreService? service,
    FirebaseFirestore? db,
  })  : _service = service ?? FirestoreService(),
        _db = db ?? FirebaseFirestore.instance;

  final FirestoreService _service;
  final FirebaseFirestore _db;

  @override
  Stream<List<Task>> watchTasks() {
    return _db
        .collection('users')
        .doc(_service.userId)
        .collection('tasks')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Task.fromMap(doc.data()))
              .toList(),
        );
  }

  @override
  Future<String> getCompletionStatus(Task task, DateTime date) =>
      _service.getCompletionStatus(task, date);

  @override
  Future<int> markTaskStatus(Task task, DateTime date, String status) =>
      _service.markTaskStatus(task, date, status);

  @override
  Future<int> clearCompletion(Task task, DateTime date) =>
      _service.clearCompletion(task, date);
}
