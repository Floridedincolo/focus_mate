import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/schedule_import_notifier.dart';
import '../../../presentation/models/schedule_import_state.dart';
import 'schedule_loading_page.dart';
import 'class_selection_page.dart';
import 'timetable_adjustment_page.dart';

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
    ref.listen<ScheduleImportState>(scheduleImportProvider, (prev, next) {
      if (!mounted) return;
      switch (next.step) {
        case ScheduleImportStep.aiLoading:
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScheduleLoadingPage()),
          );
        case ScheduleImportStep.classSelection:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ClassSelectionPage()),
          );
        case ScheduleImportStep.timetableAdjust:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TimetableAdjustmentPage()),
          );
        case ScheduleImportStep.error:
          Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
          _showError(next.errorMessage ?? 'Something went wrong.');
          ref.read(scheduleImportProvider.notifier).reset();
        default:
          break;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Import Schedule',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload a photo of your weekly timetable.',
              style: TextStyle(fontSize: 15, color: Colors.white54),
            ),
            const SizedBox(height: 24),

            // Preview
            if (_pickedImageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _pickedImageBytes!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ] else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Center(
                  child: Icon(Icons.image_outlined,
                      size: 56, color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),

            const SizedBox(height: 16),

            // Pick buttons
            Row(
              children: [
                Expanded(
                  child: _pickButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Analyse button
            _primaryButton(
              icon: Icons.auto_awesome,
              label: 'Analyse with AI',
              onPressed: _pickedImageBytes == null ? null : _analyse,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white54),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.blueAccent
              : Colors.blueAccent.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: enabled ? Colors.white : Colors.white38),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
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
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
