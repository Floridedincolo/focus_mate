import '../entities/task.dart';
import '../entities/task_completion_status.dart';
import '../repositories/task_repository.dart';
import 'task_occurrence.dart';

/// Computes the status of a [task] for a given [selectedDate].
///
/// Returns one of:
/// - [TaskCompletionStatus.hidden]: task doesn't occur on this date
/// - [TaskCompletionStatus.completed]: task was marked as completed
/// - [TaskCompletionStatus.missed]: task should have occurred but wasn't completed
/// - [TaskCompletionStatus.upcoming]: task hasn't happened yet or is still in progress
Future<TaskCompletionStatus> computeTaskStatus(
  Task task,
  DateTime selectedDate,
  TaskRepository repository,
) async {
  // Mark hidden to skip tasks not active on selected date
  if (!occursOnTask(task, selectedDate)) {
    return TaskCompletionStatus.hidden;
  }

  // Check stored completion status first
  final status = await repository.getCompletionStatus(task, selectedDate);
  if (status == TaskCompletionStatus.completed) {
    return TaskCompletionStatus.completed;
  }

  // Return the status (which is either 'missed' or 'upcoming')
  return status;
}

