import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../../domain/entities/extracted_class.dart';
import '../../widgets/schedule_import/subject_group_card.dart';
import 'schedule_preview_page.dart';

/// Step 3A — Path A (Weekly Timetable).
///
/// Shows one [SubjectGroupCard] per unique subject, grouping all
/// occurrences (e.g. Mon + Wed + Fri) of the same class together.
/// The user toggles which subjects need weekly study and sets hours.
/// Tapping "Preview Tasks" triggers [GenerateWeeklyTasksUseCase].
class TimetableAdjustmentPage extends ConsumerWidget {
  const TimetableAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleImportProvider);
    final notifier = ref.read(scheduleImportProvider.notifier);
    final classes = state.adjustedClasses;

    // Group classes by subject so the user sees one card per subject
    final Map<String, List<ExtractedClass>> grouped = {};
    for (final c in classes) {
      grouped.putIfAbsent(c.subject, () => []).add(c);
    }
    final subjects = grouped.keys.toList()..sort();

    // Navigate to preview once tasks are generated
    ref.listen<ScheduleImportState>(scheduleImportProvider, (_, next) {
      if (next.step == ScheduleImportStep.preview && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SchedulePreviewPage()),
        );
      }
      if (next.step == ScheduleImportStep.error && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Error generating tasks')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Classes'),
        leading: BackButton(onPressed: () {
          notifier.goBack();
          Navigator.of(context).pop();
        }),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Toggle which subjects need weekly study time, set '
              'how many hours per week, and mark subjects that have '
              'a final exam. We will find free slots in your schedule '
              'automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: subjects.length,
              itemBuilder: (_, i) {
                final subject = subjects[i];
                final occurrences = grouped[subject]!;
                return SubjectGroupCard(
                  occurrences: occurrences,
                  onChanged: ({
                    required bool needsHomework,
                    required double homeworkHoursPerWeek,
                    required bool hasFinalExam,
                    required DateTime? endDate,
                  }) =>
                      notifier.updateSubjectGroup(
                    subject,
                    needsHomework: needsHomework,
                    homeworkHoursPerWeek: homeworkHoursPerWeek,
                    hasFinalExam: hasFinalExam,
                    endDate: endDate,
                  ),
                  onOccurrenceEdited: (original, updated) =>
                      notifier.replaceClass(original, updated),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Preview Tasks'),
            onPressed: () => notifier.generatePreview(),
          ),
        ),
      ),
    );
  }
}
