import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/service_locator.dart';
import '../../domain/entities/extracted_class.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/extract_schedule_from_image_use_case.dart';
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

  SaveTaskUseCase get _saveTaskUseCase => getIt<SaveTaskUseCase>();

  // ── Step 1 → 2 → 3 ──────────────────────────────────────────────────────

  /// Called when the user confirms their image selection.
  /// Transitions to [aiLoading], calls Gemini, then routes to
  /// [classSelection] for the user to pick which subjects to import.
  Future<void> processImage(Uint8List imageBytes, String mimeType) async {
    state = state.copyWith(step: ScheduleImportStep.aiLoading);

    try {
      final result = await _extractUseCase(imageBytes, mimeType);

      // Collect all unique subject names for the selection step
      final allSubjects = result.classes.map((c) => c.subject).toSet();

      state = state.copyWith(
        step: ScheduleImportStep.classSelection,
        importResult: result,
        adjustedClasses: result.classes,
        selectedSubjects: allSubjects,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        step: ScheduleImportStep.error,
        errorMessage: _friendlyError(e),
      );
    }
  }

  // ── Step 2.5 — Class Selection helpers ──────────────────────────────────

  /// Toggle a single subject on/off.
  void toggleSubject(String subject) {
    final updated = Set<String>.from(state.selectedSubjects);
    if (updated.contains(subject)) {
      updated.remove(subject);
    } else {
      updated.add(subject);
    }
    state = state.copyWith(selectedSubjects: updated);
  }

  /// Select or deselect all subjects at once.
  void toggleAllSubjects(bool selectAll) {
    if (selectAll) {
      final all = state.adjustedClasses.map((c) => c.subject).toSet();
      state = state.copyWith(selectedSubjects: all);
    } else {
      state = state.copyWith(selectedSubjects: <String>{});
    }
  }

  /// Filters classes to only selected subjects and moves to timetableAdjust.
  void confirmClassSelection() {
    final filtered = state.adjustedClasses
        .where((c) => state.selectedSubjects.contains(c.subject))
        .toList();
    state = state.copyWith(
      step: ScheduleImportStep.timetableAdjust,
      adjustedClasses: filtered,
    );
  }

  // ── Step 3 helpers (timetable + exam settings) ───────────────────────────

  /// Replaces the class at [index] with [updated].
  void updateClass(int index, ExtractedClass updated) {
    final list = List<ExtractedClass>.from(state.adjustedClasses);
    list[index] = updated;
    state = state.copyWith(adjustedClasses: list);
  }

  /// Finds [original] by identity in [adjustedClasses] and replaces it with
  /// [updated]. Used when the user edits a single occurrence via the edit
  /// dialog (e.g. to fix an AI-misread subject name or time).
  void replaceClass(ExtractedClass original, ExtractedClass updated) {
    final list = List<ExtractedClass>.from(state.adjustedClasses);
    final idx = list.indexOf(original);
    if (idx != -1) {
      list[idx] = updated;
      state = state.copyWith(adjustedClasses: list);
    }
  }

  /// Updates **all** occurrences of [subject] with the given settings.
  ///
  /// This is used by the grouped subject card so that a single toggle/slider
  /// change applies uniformly to every occurrence of the same subject.
  void updateSubjectGroup(
    String subject, {
    required bool needsHomework,
    required double homeworkHoursPerWeek,
    required bool hasFinalExam,
    required DateTime? endDate,
  }) {
    final list = state.adjustedClasses.map((c) {
      if (c.subject == subject) {
        return c.copyWith(
          needsHomework: needsHomework,
          homeworkHoursPerWeek: homeworkHoursPerWeek,
          hasFinalExam: hasFinalExam,
          endDate: endDate,
        );
      }
      return c;
    }).toList();
    state = state.copyWith(adjustedClasses: list);
  }

  // ── Step 3 → 4 ──────────────────────────────────────────────────────────

  /// Generates the task list and transitions to [preview].
  /// Reads existing tasks so the slot-finder can respect already-occupied
  /// time windows.
  Future<void> generatePreview() async {
    try {
      // Await the task stream so we never schedule over existing tasks.
      // A timeout prevents hanging when Firestore is unreachable.
      List<Task> existingTasks;
      try {
        existingTasks = await ref
            .read(tasksStreamProvider.future)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Stream timed out or errored — proceed with empty list rather
        // than blocking the user indefinitely.
        existingTasks = [];
      }

      final tasks = await _generateWeeklyUseCase(
        classes: state.adjustedClasses,
        existingTasks: existingTasks,
        importDate: DateTime.now(),
      );

      state = state.copyWith(
        step: ScheduleImportStep.preview,
        previewTasks: tasks,
      );
    } catch (e) {
      state = state.copyWith(
        step: ScheduleImportStep.error,
        errorMessage: _friendlyError(e),
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
        errorMessage: _friendlyError(e),
      );
    }
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  /// Retry after an error — returns to the image picker.
  void reset() => state = const ScheduleImportState();

  /// Go back one step without resetting all state.
  void goBack() {
    switch (state.step) {
      case ScheduleImportStep.classSelection:
        state = state.copyWith(step: ScheduleImportStep.imagePicker);
      case ScheduleImportStep.timetableAdjust:
        state = state.copyWith(step: ScheduleImportStep.classSelection);
      case ScheduleImportStep.preview:
        state = state.copyWith(step: ScheduleImportStep.timetableAdjust);
      default:
        break;
    }
  }

  // ── Error formatting ─────────────────────────────────────────────────────

  /// Converts a raw exception into a user-friendly message.
  static String _friendlyError(Object e) {
    final raw = e.toString();

    // Strip the "Exception: " prefix added by Dart's Exception class.
    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }

    // If it looks like a networking / timeout issue
    if (raw.contains('SocketException') ||
        raw.contains('TimeoutException') ||
        raw.contains('ClientException')) {
      return 'Could not connect to the server. '
          'Please check your internet connection and try again.';
    }

    // If it looks like a format / parsing crash
    if (raw.contains('FormatException') || raw.contains('type \'Null\'')) {
      return 'We couldn\'t read that schedule clearly. '
          'Please ensure the image is clear and try again.';
    }

    // Generic fallback — never show raw stack traces to users.
    return 'Something went wrong. Please try again.';
  }
}

final scheduleImportProvider =
    NotifierProvider<ScheduleImportNotifier, ScheduleImportState>(
      ScheduleImportNotifier.new,
    );

