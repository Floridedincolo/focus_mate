import '../../domain/entities/extracted_class.dart';
import '../../domain/entities/extracted_exam.dart';
import '../../domain/entities/schedule_import_result.dart';
import '../../domain/entities/task.dart';

enum ScheduleImportStep {
  imagePicker,     // Step 1 — user picks an image
  aiLoading,       // Step 2 — Gemini is processing
  timetableAdjust, // Step 3A — user toggles homework per class
  examAdjust,      // Step 3B — user sets difficulty per exam
  preview,         // Step 4 — read-only preview of tasks to be created
  saving,          // Step 5 — writing to Firestore
  success,         // Step 6 — all done
  error,           // Error at any step
}

class ScheduleImportState {
  final ScheduleImportStep step;

  /// Raw result from the AI (set after step 2 completes).
  final ScheduleImportResult? importResult;

  /// Working copy of classes that the user may modify in step 3A.
  final List<ExtractedClass> adjustedClasses;

  /// Working copy of exams that the user may modify in step 3B.
  final List<ExtractedExam> adjustedExams;

  /// Generated tasks shown in the preview step — not yet saved.
  final List<Task> previewTasks;

  /// Error message shown in the error step.
  final String? errorMessage;

  const ScheduleImportState({
    this.step = ScheduleImportStep.imagePicker,
    this.importResult,
    this.adjustedClasses = const [],
    this.adjustedExams = const [],
    this.previewTasks = const [],
    this.errorMessage,
  });

  ScheduleImportState copyWith({
    ScheduleImportStep? step,
    ScheduleImportResult? importResult,
    List<ExtractedClass>? adjustedClasses,
    List<ExtractedExam>? adjustedExams,
    List<Task>? previewTasks,
    String? errorMessage,
  }) {
    return ScheduleImportState(
      step: step ?? this.step,
      importResult: importResult ?? this.importResult,
      adjustedClasses: adjustedClasses ?? this.adjustedClasses,
      adjustedExams: adjustedExams ?? this.adjustedExams,
      previewTasks: previewTasks ?? this.previewTasks,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

