import 'package:cloud_firestore/cloud_firestore.dart';
import '../task_data_source.dart';
import '../../dtos/task_dto.dart';

/// Firestore implementation of RemoteTaskDataSource
class FirebaseRemoteTaskDataSource implements RemoteTaskDataSource {
  final FirebaseFirestore _firestore;
  static const _tasksCollection = 'tasks';
  static const _statusCollection = 'task_status';

  FirebaseRemoteTaskDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<TaskDTO>> watchTasks() {
    return _firestore
        .collection(_tasksCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              TaskDTO.fromFirestore({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  @override
  Future<TaskDTO?> getTask(String taskId) async {
    final doc = await _firestore.collection(_tasksCollection).doc(taskId).get();
    if (!doc.exists) return null;
    return TaskDTO.fromFirestore({...doc.data()!, 'id': doc.id});
  }

  @override
  Future<void> saveTask(TaskDTO task) {
    return _firestore
        .collection(_tasksCollection)
        .doc(task.id)
        .set(task.toFirestore());
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _firestore.collection(_tasksCollection).doc(taskId).delete();
  }

  @override
  Future<TaskDTO?> getTaskStatus(String taskId, DateTime date) async {
    final doc = await _firestore
        .collection(_statusCollection)
        .doc('${taskId}_${date.toIso8601String()}')
        .get();
    if (!doc.exists) return null;
    // This should return TaskStatusDTO, but keeping as DTO for now
    return null;
  }

  @override
  Future<void> markTaskStatus(String taskId, DateTime date, String status) {
    final docId = '${taskId}_${date.toIso8601String()}';
    return _firestore.collection(_statusCollection).doc(docId).set({
      'taskId': taskId,
      'date': date.toIso8601String(),
      'status': status,
    });
  }

  @override
  Future<Map<String, int>> getCompletionStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = await _firestore
        .collection(_statusCollection)
        .where('date',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
            isLessThanOrEqualTo: endDate.toIso8601String())
        .get();

    final stats = <String, int>{};
    for (final doc in query.docs) {
      final status = doc['status'] as String? ?? 'pending';
      stats[status] = (stats[status] ?? 0) + 1;
    }
    return stats;
  }
}

/// In-memory implementation of LocalTaskDataSource for caching
class InMemoryLocalTaskDataSource implements LocalTaskDataSource {
  final List<TaskDTO> _cache = [];

  @override
  Stream<List<TaskDTO>> watchTasks() async* {
    yield _cache;
  }

  @override
  Future<List<TaskDTO>> getTasks() async {
    return List.from(_cache);
  }

  @override
  Future<void> saveTasks(List<TaskDTO> tasks) async {
    _cache.clear();
    _cache.addAll(tasks);
  }

  @override
  Future<TaskDTO?> getTask(String taskId) async {
    try {
      return _cache.firstWhere((task) => task.id == taskId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
  }
}

