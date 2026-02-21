import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus_mate/domain/repositories/task_repository.dart';
import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/services/firestore_service.dart';

/// Concrete implementation of [TaskRepository] using Firestore.
/// Delegates to [FirestoreService] for all low-level operations.
class FirestoreTaskRepository implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  String get _userId {
    final user = _auth.currentUser;
    return user?.uid ?? 'default_user';
  }

  @override
  Stream<List<Task>> watchTasks() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // Ensure the document ID is included in the map
            data['id'] = doc.id;
            return Task.fromMap(data);
          }).toList();
        });
  }

  @override
  Future<void> saveTask(Task task) {
    return _firestoreService.saveTask(task);
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _firestoreService.deleteTask(taskId);
  }

  @override
  Future<void> archiveTask(String taskId, bool archive) {
    return _firestoreService.archiveTask(taskId, archive);
  }

  @override
  Future<String> getCompletionStatus(Task task, DateTime date) {
    return _firestoreService.getCompletionStatus(task, date);
  }

  @override
  Future<int> markTaskStatus(Task task, DateTime date, String status) {
    return _firestoreService.markTaskStatus(task, date, status);
  }

  @override
  Future<int> clearCompletion(Task task, DateTime date) {
    return _firestoreService.clearCompletion(task, date);
  }
}
