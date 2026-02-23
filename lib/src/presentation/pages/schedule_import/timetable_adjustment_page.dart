import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../widgets/schedule_import/extracted_class_card.dart';
import 'schedule_preview_page.dart';

/// Step 3A — Path A (Weekly Timetable).
///
/// Shows every extracted class as an [ExtractedClassCard].
/// The user toggles which subjects need weekly study and sets hours.
/// Tapping "Preview Tasks" triggers [GenerateWeeklyTasksUseCase].
class TimetableAdjustmentPage extends ConsumerWidget {
  const TimetableAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleImportProvider);
    final notifier = ref.read(scheduleImportProvider.notifier);
    final classes = state.adjustedClasses;

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
              'Toggle which subjects need weekly study time. '
              'We will find free afternoon slots in your schedule automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: classes.length,
              itemBuilder: (_, i) => ExtractedClassCard(
                extractedClass: classes[i],
                onChanged: (updated) => notifier.updateClass(i, updated),
              ),
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

