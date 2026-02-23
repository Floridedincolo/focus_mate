import 'package:flutter/material.dart';

/// Step 2 — Shown while Gemini processes the image.
/// This page has no interactivity; navigation away is driven by
/// [ScheduleImportPage]'s ref.listen when the step changes.
class ScheduleLoadingPage extends StatelessWidget {
  const ScheduleLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 32),
            Text(
              'Analysing your schedule…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The AI is reading your image.\nThis usually takes a few seconds.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

