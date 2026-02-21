import '../../models/task.dart';
import '../repositories/task_repository.dart';
import 'task_occurrence.dart';

Future<String> computeTaskStatus(
  Task task,
  DateTime selectedDate,
  TaskRepository repository,
) async {
  if (!occursOnTask(task, selectedDate)) {
    return 'hidden';
  }

  final status = await repository.getCompletionStatus(task, selectedDate);
  if (status == 'completed') {
    return 'completed';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final selected =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  if (selected.isBefore(today)) {
    return 'missed';
  } else if (selected.isAfter(today)) {
    return 'upcoming';
  } else {
    if (task.endTime != null && task.startTime != null) {
      final endDay =
          task.endTime!.isBefore(task.startTime!) ? today.day + 1 : today.day;
      final taskEnd = DateTime(
        today.year,
        today.month,
        endDay,
        task.endTime!.hour,
        task.endTime!.minute,
      );
      return now.isBefore(taskEnd) ? 'upcoming' : 'missed';
    }
    return 'upcoming';
  }
}
