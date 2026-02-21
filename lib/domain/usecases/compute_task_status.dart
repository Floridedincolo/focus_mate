import 'package:focus_mate/domain/repositories/task_repository.dart';
import 'package:focus_mate/models/task.dart';
import 'task_occurrence.dart';

/// Computes the status of a [task] for a given [selectedDate].
///
/// Returns one of:
/// - 'hidden': task doesn't occur on this date
/// - 'completed': task was marked as completed
/// - 'missed': task should have occurred but wasn't completed
/// - 'upcoming': task hasn't happened yet or is still in progress
Future<String> computeTaskStatus(
  Task task,
  DateTime selectedDate,
  TaskRepository repository,
) async {
  // Mark hidden to skip tasks not active on selected date
  if (!occursOnTask(task, selectedDate)) {
    return 'hidden';
  }

  // Check stored completion status first
  final status = await repository.getCompletionStatus(task, selectedDate);
  if (status == 'completed') {
    return 'completed';
  }

  // Return the status (which is either 'missed' or 'upcoming')
  return status;
}
