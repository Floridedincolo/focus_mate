import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import 'schedule_loading_page.dart';
import 'class_selection_page.dart';
import 'timetable_adjustment_page.dart';
import 'exam_adjustment_page.dart';

/// Step 1 — Entry point for the Schedule Import wizard.
///
/// The user picks an image from the gallery or camera.
/// This widget also acts as the wizard's navigation controller:
/// it listens to [scheduleImportProvider] and pushes the correct
/// next page when [ScheduleImportStep] changes.
class ScheduleImportPage extends ConsumerStatefulWidget {
  const ScheduleImportPage({super.key});

  @override
  ConsumerState<ScheduleImportPage> createState() => _ScheduleImportPageState();
}

class _ScheduleImportPageState extends ConsumerState<ScheduleImportPage> {
  Uint8List? _pickedImageBytes;
  String _pickedMimeType = 'image/jpeg';
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    // Navigation controller — listens to step changes and drives routing
    ref.listen<ScheduleImportState>(scheduleImportProvider, (prev, next) {
      if (!mounted) return;
      switch (next.step) {
        case ScheduleImportStep.aiLoading:
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScheduleLoadingPage()),
          );
        case ScheduleImportStep.classSelection:
          // Replace loading page with subject selection page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ClassSelectionPage()),
          );
        case ScheduleImportStep.timetableAdjust:
          // Replace loading page with adjustment page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TimetableAdjustmentPage()),
          );
        case ScheduleImportStep.examAdjust:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ExamAdjustmentPage()),
          );
        case ScheduleImportStep.error:
          // Pop back to this page (loading page is on top) and show error
          Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
          _showError(next.errorMessage ?? 'Something went wrong.');
          ref.read(scheduleImportProvider.notifier).reset();
        default:
          break;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Import Schedule')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload a photo of your weekly timetable or exam schedule.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Preview the picked image
            if (_pickedImageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _pickedImageBytes!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ] else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 64),
                ),
              ),

            const SizedBox(height: 16),

            // Pick buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Analyse button
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Analyse with AI'),
              onPressed: _pickedImageBytes == null ? null : _analyse,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();
    final mime = xFile.mimeType ?? 'image/jpeg';

    setState(() {
      _pickedImageBytes = bytes;
      _pickedMimeType = mime;
    });
  }

  void _analyse() {
    if (_pickedImageBytes == null) return;
    ref
        .read(scheduleImportProvider.notifier)
        .processImage(_pickedImageBytes!, _pickedMimeType);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

