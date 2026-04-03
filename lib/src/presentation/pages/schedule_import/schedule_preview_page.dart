import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/meeting_location.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../widgets/schedule_import/task_preview_card.dart';
import 'schedule_import_success_page.dart';

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
          SnackBar(
            content: Text(next.errorMessage ?? 'Error saving tasks'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Preview',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: isSaving
            ? null
            : BackButton(
                color: Colors.white,
                onPressed: () {
                  notifier.goBack();
                  Navigator.of(context).pop();
                },
              ),
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_outlined,
                      size: 48, color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),
                  const Text('No tasks to create.',
                      style: TextStyle(color: Colors.white30, fontSize: 14)),
                ],
              ),
            )
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
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: isSaving ? null : () => notifier.saveAllTasks(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSaving
                    ? Colors.blueAccent.withValues(alpha: 0.5)
                    : Colors.blueAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSaving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isSaving ? 'Saving...' : 'Save ${tasks.length} Tasks',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
