import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../../domain/entities/extracted_class.dart';
import 'timetable_adjustment_page.dart';

/// Step 2.5 — After AI parsing, let the user pick which subjects to import.
///
/// Classes are grouped by subject name. Each group shows the subject as a
/// checkbox with a summary of its occurrences (days & times) underneath.
class ClassSelectionPage extends ConsumerWidget {
  const ClassSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleImportProvider);
    final notifier = ref.read(scheduleImportProvider.notifier);

    // Group all extracted classes by subject
    final Map<String, List<ExtractedClass>> grouped = {};
    for (final c in state.adjustedClasses) {
      grouped.putIfAbsent(c.subject, () => []).add(c);
    }

    final subjects = grouped.keys.toList()..sort();
    final selected = state.selectedSubjects;
    final allSelected = selected.length == subjects.length && subjects.isNotEmpty;

    // Navigate to timetableAdjust when confirmed
    ref.listen<ScheduleImportState>(scheduleImportProvider, (_, next) {
      if (next.step == ScheduleImportStep.timetableAdjust && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TimetableAdjustmentPage()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Classes'),
        leading: BackButton(onPressed: () {
          notifier.goBack();
          Navigator.of(context).pop();
        }),
        actions: [
          TextButton(
            onPressed: () => notifier.toggleAllSubjects(!allSelected),
            child: Text(allSelected ? 'Deselect All' : 'Select All'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'We found ${subjects.length} subjects in your timetable. '
              'Select the ones you want to import.',
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
                final isSelected = selected.contains(subject);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => notifier.toggleSubject(subject),
                    title: Text(
                      subject,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _buildOccurrenceSummary(occurrences),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
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
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              selected.isEmpty
                  ? 'Select at least 1 subject'
                  : 'Continue with ${selected.length} subject${selected.length == 1 ? '' : 's'}',
            ),
            onPressed: selected.isEmpty
                ? null
                : () => notifier.confirmClassSelection(),
          ),
        ),
      ),
    );
  }

  /// Build a human-readable summary like "Mon 09:00–10:00, Wed 09:00–10:00"
  String _buildOccurrenceSummary(List<ExtractedClass> occurrences) {
    final parts = occurrences.map((c) {
      final start = _fmt(c.startTime);
      final end = _fmt(c.endTime);
      final room = c.room != null ? ' (${c.room})' : '';
      return '${c.day} $start–$end$room';
    }).toList();
    return parts.join(', ');
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

