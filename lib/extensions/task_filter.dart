import 'package:focus_mate/models/task.dart';
import 'package:focus_mate/domain/usecases/task_occurrence.dart';

extension TaskFilter on Task {
  bool occursOn(DateTime date) => occursOnTask(this, date);
}
