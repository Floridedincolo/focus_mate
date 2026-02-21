import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/domain/usecases/task_occurrence.dart';

extension TaskFilter on Task {
  /// Determines whether this task occurs on [date].
  /// Delegates to the pure function [occursOnTask] for testability.
  bool occursOn(DateTime date) => occursOnTask(this, date);
}
