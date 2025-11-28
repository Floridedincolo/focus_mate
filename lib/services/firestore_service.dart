import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus_mate/extensions/task_filter.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;
    return user?.uid ?? 'default_user';
  }
  String _dateId(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  DateTime? _previousOccurrence(Task task, DateTime from) {
    DateTime current = from.subtract(const Duration(days: 1));
    final min = DateTime(task.startDate.year, task.startDate.month, task.startDate.day);
    while (current.isAfter(min) || current.isAtSameMomentAs(min)) {
      if (task.occursOn(current)) return current;
      current = current.subtract(const Duration(days: 1));
    }
    return null;
  }

  Future<int> _countConsecutiveCompletions(Task task, DateTime start) async {
    final taskRef = _db.collection('users').doc(userId).collection('tasks').doc(task.id);
    int count = 0;
    DateTime? cursor = start;

    while (cursor != null &&
        (cursor.isAfter(task.startDate) || cursor.isAtSameMomentAs(task.startDate))) {
      final doc = await taskRef.collection('completions').doc(_dateId(cursor)).get();
      if (doc.exists && doc.data()?['status'] == 'completed') {
        count++;
        cursor = _previousOccurrence(task, cursor);
      } else {
        break;
      }
    }
    return count;
  }

  /// --- Operații principale ---

  Future<void> saveTask(Task task) async {
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id);

    await docRef.set(task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  Future<void> archiveTask(String taskId, bool archive) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .update({'archived': archive});
  }

  Future<String> getCompletionStatus(Task task, DateTime date) async {
    final dateId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id)
        .collection('completions')
        .doc(dateId);

    final doc = await docRef.get();

    if (doc.exists) {
      return doc.data()?['status'] ?? 'upcoming';
    }

    // Dacă nu există completare:
    final today = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);

    // Dacă ziua e trecută și taskul trebuia să aibă loc, e "missed"
    if (dateOnly.isBefore(todayOnly) && task.occursOn(date)) {
      return 'missed';
    }

    // Altfel (viitor sau nu trebuia făcut atunci)
    return 'upcoming';
  }


  /// Marchează o zi ca "completed" sau alt status
  /// Returnează noul streak
  Future<int> markTaskStatus(Task task, DateTime date, String status) async {
    final taskRef = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id);

    final completionRef = taskRef
        .collection('completions')
        .doc(_dateId(date));

    await completionRef.set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    int newStreak = 0;
    if (status == 'completed') {
      newStreak = await _countConsecutiveCompletions(task, date);
      await taskRef.update({
        'streak': newStreak,
        'lastCompletionDate': date,
      });
    } else {
      final prev = _previousOccurrence(task, date);
      newStreak = prev != null ? await _countConsecutiveCompletions(task, prev) : 0;
      await taskRef.update({'streak': newStreak});
    }

    return newStreak;
  }

  /// Șterge completarea pentru o zi și recalculează streak-ul
  Future<int> clearCompletion(Task task, DateTime date) async {
    final taskRef = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id);

    final docRef = taskRef
        .collection('completions')
        .doc(_dateId(date));

    await docRef.delete();

    final prev = _previousOccurrence(task, date);
    final newStreak = prev != null ? await _countConsecutiveCompletions(task, prev) : 0;

    await taskRef.update({'streak': newStreak});
    return newStreak;
  }
}
