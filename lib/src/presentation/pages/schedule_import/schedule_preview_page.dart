import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../widgets/schedule_import/task_preview_card.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../../domain/entities/meeting_location.dart';
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
              itemBuilder: (_, i) => TaskPreviewCard(
                task: tasks[i],
                onEditLocation: () =>
                    _showEditLocationSheet(context, notifier, i, tasks[i]),
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

  /// Shows a bottom sheet with a full LocationAutocompleteField so the user
  /// gets real Google Places suggestions (and we capture lat/lng).
  void _showEditLocationSheet(
    BuildContext context,
    ScheduleImportNotifier notifier,
    int index,
    dynamic task,
  ) {
    MeetingLocation? selectedLocation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LocationAutocompleteField(
                    initialLocationName: task.locationName,
                    onLocationSelected: (loc) {
                      setSheetState(() => selectedLocation = loc);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (selectedLocation != null) {
                              notifier.updatePreviewTaskLocation(
                                index,
                                selectedLocation!.name,
                                latitude: selectedLocation!.latitude,
                                longitude: selectedLocation!.longitude,
                              );
                            }
                            Navigator.pop(ctx);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

