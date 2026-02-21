import '../../models/task.dart';

/// Abstract repository that provides task data to the UI layer.
///
/// Concrete implementations (e.g. [FirestoreTaskRepository]) handle the
/// actual persistence mechanism so that the UI never depends on Firestore
/// directly.
abstract class TaskRepository {
  /// Emits the full, up-to-date list of tasks whenever the underlying data
  /// changes.
  Stream<List<Task>> watchTasks();

  /// Returns the persisted completion status for [task] on [date].
  ///
  /// Returns `'upcoming'` when no record has been stored yet.
  Future<String> getCompletionStatus(Task task, DateTime date);

  /// Persists [status] for [task] on [date] and returns the updated streak.
  Future<int> markTaskStatus(Task task, DateTime date, String status);

  /// Removes the completion record for [task] on [date] and returns the
  /// recalculated streak.
  Future<int> clearCompletion(Task task, DateTime date);
}
