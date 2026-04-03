import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';

class ScheduleImportSuccessPage extends ConsumerWidget {
  const ScheduleImportSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 36, color: Colors.greenAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'Schedule Imported!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your tasks have been added to your schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 40),
              // Back to Home
              GestureDetector(
                onTap: () {
                  ref.read(scheduleImportProvider.notifier).reset();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Back to Home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Import Another
              GestureDetector(
                onTap: () {
                  ref.read(scheduleImportProvider.notifier).reset();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  Navigator.of(context).pushNamed('/import-schedule');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Import Another Schedule',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
