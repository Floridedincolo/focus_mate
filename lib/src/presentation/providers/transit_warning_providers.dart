import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/compute_transit_warnings_use_case.dart';

final transitWarningsProvider = StateNotifierProvider<TransitWarningsNotifier,
    Map<int, TransitWarning>>((ref) {
  return TransitWarningsNotifier(getIt<ComputeTransitWarningsUseCase>());
});

class TransitWarningsNotifier
    extends StateNotifier<Map<int, TransitWarning>> {
  final ComputeTransitWarningsUseCase _useCase;
  List<String>? _lastTaskSignatures;

  TransitWarningsNotifier(this._useCase) : super({});

  /// Recomputes warnings when the task list (or relevant fields) change.
  Future<void> compute(List<Task> sortedTasks) async {
    print('📡 Providerul a fost apelat cu ${sortedTasks.length} task-uri.');

    // Creăm o "amprentă" unică pentru fiecare task care ne interesează
    // Dacă utilizatorul schimbă ora sau locația, această semnătură se va schimba!
    final signatures = sortedTasks.map((t) {
      final start = t.startTime != null ? '${t.startTime!.hour}:${t.startTime!.minute}' : 'null';
      final end = t.endTime != null ? '${t.endTime!.hour}:${t.endTime!.minute}' : 'null';
      final loc = '${t.locationLatitude}_${t.locationLongitude}';
      return '${t.id}_${start}_${end}_$loc';
    }).toList();

    if (_signaturesEqual(_lastTaskSignatures, signatures)) {
      print('🔄 Lista și orele sunt la fel ca înainte. Nu recalculez traficul.');
      return;
    }

    print('✨ Date modificate detectate! Încep recalcularea traficului...');
    _lastTaskSignatures = signatures;

    final warnings = await _useCase(sortedTasks);
    if (mounted) state = warnings;
  }

  void reset() {
    _lastTaskSignatures = null;
    state = {};
  }

  bool _signaturesEqual(List<String>? a, List<String>? b) {
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}