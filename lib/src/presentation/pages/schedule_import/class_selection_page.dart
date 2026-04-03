import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../../domain/entities/extracted_class.dart';
import 'timetable_adjustment_page.dart';

class ClassSelectionPage extends ConsumerWidget {
  const ClassSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleImportProvider);
    final notifier = ref.read(scheduleImportProvider.notifier);

    final Map<String, List<ExtractedClass>> grouped = {};
    for (final c in state.adjustedClasses) {
      grouped.putIfAbsent(c.subject, () => []).add(c);
    }

    final subjects = grouped.keys.toList()..sort();
    final selected = state.selectedSubjects;
    final allSelected = selected.length == subjects.length && subjects.isNotEmpty;

    ref.listen<ScheduleImportState>(scheduleImportProvider, (_, next) {
      if (next.step == ScheduleImportStep.timetableAdjust && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TimetableAdjustmentPage()),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Select Classes',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: BackButton(
          color: Colors.white,
          onPressed: () {
            notifier.goBack();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => notifier.toggleAllSubjects(!allSelected),
            child: Text(
              allSelected ? 'Deselect All' : 'Select All',
              style: const TextStyle(color: Colors.blueAccent, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'We found ${subjects.length} subjects in your timetable. '
              'Select the ones you want to import.',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
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

                return GestureDetector(
                  onTap: () => notifier.toggleSubject(subject),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.blueAccent.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Checkbox
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blueAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? null
                                : Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 15, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _buildOccurrenceSummary(occurrences),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white30, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: selected.isEmpty
                ? null
                : () => notifier.confirmClassSelection(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: selected.isEmpty
                    ? Colors.blueAccent.withValues(alpha: 0.3)
                    : Colors.blueAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward, size: 18,
                      color: selected.isEmpty ? Colors.white38 : Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    selected.isEmpty
                        ? 'Select at least 1 subject'
                        : 'Continue with ${selected.length} subject${selected.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: selected.isEmpty ? Colors.white38 : Colors.white,
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

  String _buildOccurrenceSummary(List<ExtractedClass> occurrences) {
    final parts = occurrences.map((c) {
      final start = _fmt(c.startTime);
      final end = _fmt(c.endTime);
      final room = c.room != null ? ' (${c.room})' : '';
      return '${c.day} $start\u2013$end$room';
    }).toList();
    return parts.join(', ');
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
