import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import '../../../domain/entities/extracted_class.dart';
import '../../widgets/schedule_import/subject_group_card.dart';
import 'schedule_preview_page.dart';

class TimetableAdjustmentPage extends ConsumerWidget {
  const TimetableAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleImportProvider);
    final notifier = ref.read(scheduleImportProvider.notifier);
    final classes = state.adjustedClasses;

    final Map<String, List<ExtractedClass>> grouped = {};
    for (final c in classes) {
      grouped.putIfAbsent(c.subject, () => []).add(c);
    }
    final subjects = grouped.keys.toList()..sort();

    ref.listen<ScheduleImportState>(scheduleImportProvider, (_, next) {
      if (next.step == ScheduleImportStep.preview && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SchedulePreviewPage()),
        );
      }
      if (next.step == ScheduleImportStep.error && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Error generating tasks'),
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
        title: const Text('Your Classes',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: BackButton(
          color: Colors.white,
          onPressed: () {
            notifier.goBack();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Toggle which subjects need weekly study time, set '
              'how many hours per week, and mark subjects that have '
              'a final exam.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
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
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () => notifier.generatePreview(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.preview_outlined, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Preview Tasks',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
