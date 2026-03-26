import '../../data/datasources/transit_route_service.dart';
import '../entities/meeting_location.dart';
import '../entities/task.dart';

typedef TransitWarning = ({int transitMin, int availableMin});

class ComputeTransitWarningsUseCase {
  final TransitRouteService _transitService;

  const ComputeTransitWarningsUseCase(this._transitService);

  /// Returns a map keyed by task-list index for every task where
  /// the travel time from the previous task exceeds the available gap.
  Future<Map<int, TransitWarning>> call(List<Task> sortedTasks) async {
    final warnings = <int, TransitWarning>{};

    for (int i = 0; i < sortedTasks.length - 1; i++) {
      final taskA = sortedTasks[i];
      final taskB = sortedTasks[i + 1];

      if (taskA.endTime == null || taskB.startTime == null) continue;
      if (taskA.locationLatitude == null || taskA.locationLongitude == null) continue;
      if (taskB.locationLatitude == null || taskB.locationLongitude == null) continue;

      final endMin = taskA.endTime!.hour * 60 + taskA.endTime!.minute;
      final startMin = taskB.startTime!.hour * 60 + taskB.startTime!.minute;
      final gap = startMin - endMin;
      if (gap <= 0) continue;

      try {
        final origin = MeetingLocation(
          name: taskA.locationName ?? '',
          latitude: taskA.locationLatitude,
          longitude: taskA.locationLongitude,
        );
        final destination = MeetingLocation(
          name: taskB.locationName ?? '',
          latitude: taskB.locationLatitude,
          longitude: taskB.locationLongitude,
        );

        final transitMin = await _transitService.getTransitTimeMinutes(
          origin: origin, destination: destination, mode: 'DRIVE',
        );

        if (transitMin != null && transitMin > gap) {
          warnings[i + 1] = (transitMin: transitMin, availableMin: gap);
        }
      } catch (_) {}
    }

    return warnings;
  }
}
