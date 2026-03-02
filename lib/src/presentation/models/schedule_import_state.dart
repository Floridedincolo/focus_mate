import '../../domain/entities/extracted_class.dart';
import '../../domain/entities/extracted_class.dart';
import '../../domain/entities/schedule_import_result.dart';
import '../../domain/entities/task.dart';

enum ScheduleImportStep {
  imagePicker,     // Step 1 — user picks an image
  aiLoading,       // Step 2 — Gemini is processing
  classSelection,  // Step 2.5 — user picks which subjects to import
  timetableAdjust, // Step 3 — user toggles homework & exam per class
  preview,         // Step 4 — read-only preview of tasks to be created
  saving,          // Step 5 — writing to Firestore
  success,         // Step 6 — all done
  error,           // Error at any step
}

class ScheduleImportState {
  final ScheduleImportStep step;

  /// Raw result from the AI (set after step 2 completes).
  final ScheduleImportResult? importResult;

  /// Working copy of classes that the user may modify in step 3.
  final List<ExtractedClass> adjustedClasses;

  /// Generated tasks shown in the preview step — not yet saved.
  final List<Task> previewTasks;

  /// Subjects the user has selected for import (classSelection step).
  final Set<String> selectedSubjects;

  /// Error message shown in the error step.
  final String? errorMessage;

  const ScheduleImportState({
    this.step = ScheduleImportStep.imagePicker,
    this.importResult,
    this.adjustedClasses = const [],
    this.previewTasks = const [],
    this.selectedSubjects = const {},
    this.errorMessage,
  });

  ScheduleImportState copyWith({
    ScheduleImportStep? step,
    ScheduleImportResult? importResult,
    List<ExtractedClass>? adjustedClasses,
    List<Task>? previewTasks,
    Set<String>? selectedSubjects,
    String? errorMessage,
  }) {
    return ScheduleImportState(
      step: step ?? this.step,
      importResult: importResult ?? this.importResult,
      adjustedClasses: adjustedClasses ?? this.adjustedClasses,
      previewTasks: previewTasks ?? this.previewTasks,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

