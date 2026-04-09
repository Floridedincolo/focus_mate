import 'package:flutter/material.dart';
import '../entities/task.dart';
import '../entities/task_completion_status.dart';
import '../repositories/task_repository.dart';

Future<TaskCompletionStatus> computeTaskStatus(
    Task task,
    DateTime selectedDate,
    TaskRepository taskRepository,
    ) async {
  // Ignorăm complet task-urile arhivate
  if (task.archived) return TaskCompletionStatus.hidden;

  final now = DateTime.now();

  // 1. Verificăm dacă există o supra-scriere în Firestore pentru data selectată (ex: a fost marcat "Done")
  final overrideStatus = await taskRepository.getCompletionStatus(task, selectedDate);
  if (overrideStatus != null) return overrideStatus;

  // 2. Normalizăm datele pentru a compara corect "zilele" (fără ore/minute)
  final justSelected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final justToday = DateTime(now.year, now.month, now.day);

  // 3. Logică: Zile trecute -> MISSED
  // Dacă ziua selectată e strict înainte de ziua de azi, task-ul nerezolvat e considerat pierdut.
  if (justSelected.isBefore(justToday)) {
    return TaskCompletionStatus.missed;
  }

  // 4. Logică pentru ZIUA CURENTĂ
  if (justSelected.isAtSameMomentAs(justToday)) {
    if (task.startTime != null && task.endTime != null) {
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
      final endMinutes = task.endTime!.hour * 60 + task.endTime!.minute;

      // Dacă a trecut deja ora de final și nu l-am bifat -> MISSED
      if (nowMinutes > endMinutes) {
        return TaskCompletionStatus.missed;
      }

      // Observație: Partea de detectare a "In Progress" se face direct în interfață
      // (TaskItem) bazat pe curentActiveTaskProvider. Din baza de date, el apare ca UPCOMING.
      return TaskCompletionStatus.upcoming;
    } else {
      // Dacă task-ul e pentru azi, dar nu are ore specifice, rămâne Upcoming până la sfârșitul zilei.
      return TaskCompletionStatus.upcoming;
    }
  }

  // 5. Logică pentru Zilele din Viitor
  // Dacă e o zi din viitor, e mereu UPCOMING.
  return TaskCompletionStatus.upcoming;
}