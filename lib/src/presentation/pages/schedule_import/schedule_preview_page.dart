import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/meeting_location.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../widgets/schedule_import/task_preview_card.dart';
import 'schedule_import_success_page.dart';

/// Step 4 — Preview of all tasks that will be created.
/// Each task shows its auto-filled location (from saved work location)
/// which the user can tap to edit via a bottom sheet with autocomplete.
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
              itemBuilder: (_, i) => TaskPreviewCard(
                task: tasks[i],
                onEditLocation: () =>
                    _showEditLocationSheet(context, ref, i),
              ),
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

  void _showEditLocationSheet(
      BuildContext context, WidgetRef ref, int index) {
    final task = ref.read(scheduleImportProvider).previewTasks[index];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location for "${task.title}"',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LocationAutocompleteField(
              initialLocationName: task.locationName,
              onLocationSelected: (MeetingLocation? loc) {
                final notifier =
                    ref.read(scheduleImportProvider.notifier);
                if (loc != null) {
                  notifier.updatePreviewTaskLocation(
                    index,
                    loc.name,
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                  );
                } else {
                  notifier.updatePreviewTaskLocation(index, '');
                }
                Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
