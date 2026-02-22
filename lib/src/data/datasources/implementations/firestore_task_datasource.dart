import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../task_data_source.dart';
import '../../dtos/task_dto.dart';

/// Firestore implementation of RemoteTaskDataSource
class FirebaseRemoteTaskDataSource implements RemoteTaskDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseRemoteTaskDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _userId {
    final user = _auth.currentUser;
    return user?.uid ?? 'default_user';
  }

  String _dateId(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Stream<List<TaskDTO>> watchTasks() {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TaskDTO.fromFirestore(data);
      }).toList();
    });
  }

  @override
  Future<void> saveTask(TaskDTO task) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(task.id)
        .set(task.toFirestore());
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  @override
  Future<void> archiveTask(String taskId, bool archive) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(taskId)
        .update({'archived': archive});
  }

  @override
  Future<String> getCompletionStatus(String taskId, DateTime date) async {
    final dateId = _dateId(date);
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(taskId)
        .collection('completions')
        .doc(dateId);

    final doc = await docRef.get();

    if (doc.exists) {
      return doc.data()?['status'] ?? 'upcoming';
    }

    final today = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (dateOnly.isBefore(todayOnly)) {
      return 'missed';
    }

    return 'upcoming';
  }

  @override
  Future<int> markTaskStatus(TaskDTO task, DateTime date, String status) async {
    final taskRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(task.id);

    final completionRef =
        taskRef.collection('completions').doc(_dateId(date));

    await completionRef.set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    int newStreak = 0;
    if (status == 'completed') {
      newStreak = await _countConsecutiveCompletions(task, date);
      await taskRef.update({'streak': newStreak, 'lastCompletionDate': date});
    } else {
      final prev = _previousOccurrence(task, date);
      newStreak = prev != null
          ? await _countConsecutiveCompletions(task, prev)
          : 0;
      await taskRef.update({'streak': newStreak});
    }

    return newStreak;
  }

  @override
  Future<int> clearCompletion(TaskDTO task, DateTime date) async {
    final taskRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(task.id);

    final docRef = taskRef.collection('completions').doc(_dateId(date));
    await docRef.delete();

    final prev = _previousOccurrence(task, date);
    final newStreak = prev != null
        ? await _countConsecutiveCompletions(task, prev)
        : 0;

    await taskRef.update({'streak': newStreak});
    return newStreak;
  }

  // --- Helpers for streak calculation ---

  DateTime? _previousOccurrence(TaskDTO task, DateTime from) {
    DateTime current = from.subtract(const Duration(days: 1));
    final min = DateTime(
      task.startDate.year,
      task.startDate.month,
      task.startDate.day,
    );
    while (current.isAfter(min) || current.isAtSameMomentAs(min)) {
      if (_taskOccursOn(task, current)) return current;
      current = current.subtract(const Duration(days: 1));
    }
    return null;
  }

  Future<int> _countConsecutiveCompletions(
      TaskDTO task, DateTime start) async {
    final taskRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(task.id);
    int count = 0;
    DateTime? cursor = start;

    while (cursor != null &&
        (cursor.isAfter(task.startDate) ||
            cursor.isAtSameMomentAs(task.startDate))) {
      final doc = await taskRef
          .collection('completions')
          .doc(_dateId(cursor))
          .get();
      if (doc.exists && doc.data()?['status'] == 'completed') {
        count++;
        cursor = _previousOccurrence(task, cursor);
      } else {
        break;
      }
    }
    return count;
  }

  /// Determines whether a task (at DTO level) occurs on [date].
  bool _taskOccursOn(TaskDTO task, DateTime date) {
    final targetDay = date.weekday;
    final isSameDay = date.year == task.startDate.year &&
        date.month == task.startDate.month &&
        date.day == task.startDate.day;

    if (task.oneTime) return isSameDay;

    switch (task.repeatType) {
      case 'daily':
        return !date.isBefore(task.startDate);
      case 'weekly':
        final difference = date.difference(task.startDate).inDays;
        return difference >= 0 && difference % 7 == 0;
      case 'custom':
        final weekdays = [
          "Monday", "Tuesday", "Wednesday", "Thursday",
          "Friday", "Saturday", "Sunday",
        ];
        return task.days[weekdays[targetDay - 1]] == true &&
            !date.isBefore(task.startDate);
      default:
        return false;
    }
  }
}

/// In-memory implementation of LocalTaskDataSource for caching
class InMemoryLocalTaskDataSource implements LocalTaskDataSource {
  final List<TaskDTO> _cache = [];

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

