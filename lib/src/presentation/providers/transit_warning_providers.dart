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
  List<String>? _lastTaskIds;

  TransitWarningsNotifier(this._useCase) : super({});

  /// Recomputes warnings only when the task list has changed.
  Future<void> compute(List<Task> sortedTasks) async {
    final ids = sortedTasks.map((t) => t.id).toList();
    if (_idsEqual(_lastTaskIds, ids)) return;
    _lastTaskIds = ids;

    final warnings = await _useCase(sortedTasks);
    if (mounted) state = warnings;
  }

  void reset() {
    _lastTaskIds = null;
    state = {};
  }

  bool _idsEqual(List<String>? a, List<String>? b) {
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
