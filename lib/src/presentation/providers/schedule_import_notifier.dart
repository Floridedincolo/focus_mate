import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/service_locator.dart';
import '../../domain/entities/extracted_class.dart';
import '../../domain/entities/extracted_exam.dart';
import '../../domain/entities/schedule_type.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/extract_schedule_from_image_use_case.dart';
import '../../domain/usecases/generate_exam_prep_tasks_use_case.dart';
import '../../domain/usecases/generate_weekly_tasks_use_case.dart';
import '../../domain/usecases/task_usecases.dart';
import '../models/schedule_import_state.dart';
import 'task_providers.dart';

/// Drives the entire Schedule Import wizard.
///
/// Navigation pattern:
///   Widgets listen to [step] and push/pop pages accordingly using
///   a [ref.listen] in the root wizard widget. Pages themselves never
///   import other pages — they only call methods on this notifier.
class ScheduleImportNotifier extends Notifier<ScheduleImportState> {
  @override
  ScheduleImportState build() => const ScheduleImportState();

  // ── Use cases (lazily resolved from GetIt) ───────────────────────────────

  ExtractScheduleFromImageUseCase get _extractUseCase =>
      getIt<ExtractScheduleFromImageUseCase>();

  GenerateWeeklyTasksUseCase get _generateWeeklyUseCase =>
      getIt<GenerateWeeklyTasksUseCase>();

  GenerateExamPrepTasksUseCase get _generateExamUseCase =>
      getIt<GenerateExamPrepTasksUseCase>();

  SaveTaskUseCase get _saveTaskUseCase => getIt<SaveTaskUseCase>();

  // ── Step 1 → 2 → 3 ──────────────────────────────────────────────────────

  /// Called when the user confirms their image selection.
  /// Transitions to [aiLoading], calls Gemini, then routes to the
  /// appropriate adjustment step based on schedule type.
  Future<void> processImage(Uint8List imageBytes, String mimeType) async {
    state = state.copyWith(step: ScheduleImportStep.aiLoading);

    try {
      final result = await _extractUseCase(imageBytes, mimeType);
      state = state.copyWith(
        step: result.type == ScheduleType.weeklyTimetable
            ? ScheduleImportStep.timetableAdjust
            : ScheduleImportStep.examAdjust,
        importResult: result,
        adjustedClasses: result.classes ?? [],
        adjustedExams: result.exams ?? [],
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        step: ScheduleImportStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Step 3A helpers (timetable) ──────────────────────────────────────────

  /// Replaces the class at [index] with [updated].
  void updateClass(int index, ExtractedClass updated) {
    final list = List<ExtractedClass>.from(state.adjustedClasses);
    list[index] = updated;
    state = state.copyWith(adjustedClasses: list);
  }

  // ── Step 3B helpers (exams) ──────────────────────────────────────────────

  /// Replaces the exam at [index] with [updated].
  void updateExam(int index, ExtractedExam updated) {
    final list = List<ExtractedExam>.from(state.adjustedExams);
    list[index] = updated;
    state = state.copyWith(adjustedExams: list);
  }

  // ── Step 3 → 4 ──────────────────────────────────────────────────────────

  /// Generates the task list and transitions to [preview].
  /// For Path A this also reads existing tasks so the slot-finder
  /// can respect already-occupied time windows.
  Future<void> generatePreview() async {
    try {
      final List<Task> tasks;

      if (state.importResult?.type == ScheduleType.weeklyTimetable) {
        // Read the current task list from the stream provider synchronously
        // (it's already cached by Riverpod after the home page loaded it).
        final existingAsync = ref.read(tasksStreamProvider);
        final existingTasks = existingAsync.valueOrNull ?? [];

        tasks = await _generateWeeklyUseCase(
          classes: state.adjustedClasses,
          existingTasks: existingTasks,
          importDate: DateTime.now(),
        );
      } else {
        tasks = await _generateExamUseCase(
          exams: state.adjustedExams,
          today: DateTime.now(),
        );
      }

      state = state.copyWith(
        step: ScheduleImportStep.preview,
        previewTasks: tasks,
      );
    } catch (e) {
      state = state.copyWith(
        step: ScheduleImportStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Step 4 → 5 → 6 ──────────────────────────────────────────────────────

  /// Saves all preview tasks to Firestore and transitions to [success].
  Future<void> saveAllTasks() async {
    state = state.copyWith(step: ScheduleImportStep.saving);
    try {
      for (final task in state.previewTasks) {
        await _saveTaskUseCase(task);
      }
      // Invalidate the task stream so the home page refreshes
      ref.invalidate(tasksStreamProvider);
      state = state.copyWith(step: ScheduleImportStep.success);
    } catch (e) {
      state = state.copyWith(
        step: ScheduleImportStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  /// Retry after an error — returns to the image picker.
  void reset() => state = const ScheduleImportState();

  /// Go back one step without resetting all state.
  void goBack() {
    switch (state.step) {
      case ScheduleImportStep.timetableAdjust:
      case ScheduleImportStep.examAdjust:
        state = state.copyWith(step: ScheduleImportStep.imagePicker);
      case ScheduleImportStep.preview:
        state = state.copyWith(
          step: state.importResult?.type == ScheduleType.weeklyTimetable
              ? ScheduleImportStep.timetableAdjust
              : ScheduleImportStep.examAdjust,
        );
      default:
        break;
    }
  }
}

final scheduleImportProvider =
    NotifierProvider<ScheduleImportNotifier, ScheduleImportState>(
      ScheduleImportNotifier.new,
    );

