import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/schedule_import_notifier.dart';

/// Step 6 — Shown after all tasks have been saved successfully.
class ScheduleImportSuccessPage extends ConsumerWidget {
  const ScheduleImportSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'Schedule Imported!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your tasks have been added to your schedule.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to Home'),
                onPressed: () {
                  // Reset wizard state so it's fresh next time
                  ref.read(scheduleImportProvider.notifier).reset();
                  if (!context.mounted) return;
                  try {
                    // Safely pop all wizard pages back to the root
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  } catch (_) {
                    // Fallback: if popUntil fails (e.g. no matching route),
                    // push home and clear the entire stack.
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (_) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.read(scheduleImportProvider.notifier).reset();
                  if (!context.mounted) return;
                  try {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  } catch (_) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (_) => false,
                    );
                  }
                },
                child: const Text('Import Another Schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

