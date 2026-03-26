import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../widgets/schedule_import/task_preview_card.dart';
import 'schedule_import_success_page.dart';

/// Step 4 — Read-only preview of all tasks that will be created.
/// The user can go back and adjust, or confirm and save.
class SchedulePreviewPage extends ConsumerWidget {
  const SchedulePreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleImportProvider);
    final notifier = ref.read(scheduleImportProvider.notifier);
    final tasks = state.previewTasks;
    final isSaving = state.step == ScheduleImportStep.saving;

    ref.listen<ScheduleImportState>(scheduleImportProvider, (_, next) {
      if (next.step == ScheduleImportStep.success && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScheduleImportSuccessPage()),
        );
      }
      if (next.step == ScheduleImportStep.error && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Error saving tasks')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        leading: isSaving
            ? null
            : BackButton(onPressed: () {
                notifier.goBack();
                Navigator.of(context).pop();
              }),
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('No tasks to create.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tasks.length,
              itemBuilder: (_, i) => TaskPreviewCard(task: tasks[i]),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? 'Saving…' : 'Save ${tasks.length} Tasks'),
            onPressed: isSaving ? null : () => notifier.saveAllTasks(),
          ),
        ),
      ),
    );
  }
}

