import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../widgets/schedule_import/extracted_exam_card.dart';
import 'schedule_preview_page.dart';

/// Step 3B — Path B (Exam Schedule).
///
/// Shows every extracted exam as an [ExtractedExamCard].
/// The user sets each exam's difficulty, which drives how many
/// study sessions [GenerateExamPrepTasksUseCase] will create.
class ExamAdjustmentPage extends ConsumerWidget {
  const ExamAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleImportProvider);
    final notifier = ref.read(scheduleImportProvider.notifier);
    final exams = state.adjustedExams;

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
        title: const Text('Your Exams'),
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
              'Rate the difficulty of each exam. '
              'Harder exams get more study sessions spread over the coming days.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: exams.length,
              itemBuilder: (_, i) => ExtractedExamCard(
                exam: exams[i],
                onChanged: (updated) => notifier.updateExam(i, updated),
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

