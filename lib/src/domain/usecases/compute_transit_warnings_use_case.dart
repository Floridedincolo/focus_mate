import '../../data/datasources/transit_route_service.dart';
import '../entities/meeting_location.dart';
import '../entities/task.dart';

typedef TransitWarning = ({int transitMin, int availableMin, String mode});

class ComputeTransitWarningsUseCase {
  final TransitRouteService _transitService;

  const ComputeTransitWarningsUseCase(this._transitService);

  /// Returns a map keyed by task-list index for every task where
  /// the travel time from the previous task exceeds the available gap.
  Future<Map<int, TransitWarning>> call(List<Task> sortedTasks) async {
    final warnings = <int, TransitWarning>{};
    Task? lastTaskWithLocation;

    print('🔍 UseCase-ul a primit ${sortedTasks.length} task-uri pentru analiză.');

    for (int i = 0; i < sortedTasks.length; i++) {
      final currentTask = sortedTasks[i];

      // SUPER-DEBUG: Printăm ce are în "burtă" fiecare task
      print('▶️ Task ${i+1}: "${currentTask.title ?? currentTask.id}"');
      print('   - Start Time: ${currentTask.startTime}');
      print('   - End Time: ${currentTask.endTime}');
      print('   - Locație (Nume): ${currentTask.locationName}');
      print('   - Lat/Lng GPS: ${currentTask.locationLatitude}, ${currentTask.locationLongitude}');

      if (currentTask.startTime == null ||
          currentTask.locationLatitude == null ||
          currentTask.locationLongitude == null) {
        print('   ⏭️ SĂRIT PESTE: Îi lipsesc orele sau coordonatele GPS!');
        continue;
      }

      if (lastTaskWithLocation != null && lastTaskWithLocation.endTime != null) {
        final endMin = lastTaskWithLocation.endTime!.hour * 60 + lastTaskWithLocation.endTime!.minute;
        final startMin = currentTask.startTime!.hour * 60 + currentTask.startTime!.minute;
        final gap = startMin - endMin;

        try {
          final origin = MeetingLocation(
            name: lastTaskWithLocation.locationName ?? '',
            latitude: lastTaskWithLocation.locationLatitude,
            longitude: lastTaskWithLocation.locationLongitude,
          );
          final destination = MeetingLocation(
            name: currentTask.locationName ?? '',
            latitude: currentTask.locationLatitude,
            longitude: currentTask.locationLongitude,
          );

          print('🚗 OK! Tranzit de la "${origin.name}" la "${destination.name}". Timp liber: $gap min.');

          final transitMin = await _transitService.getTransitTimeMinutes(
            origin: origin,
            destination: destination,
            mode: 'DRIVE',
          );

          print('⏱️ Google răspunde: $transitMin min.');

          if (transitMin != null && transitMin > gap) {
            warnings[i] = (transitMin: transitMin, availableMin: gap, mode: 'DRIVE');
            print('⚠️ AVERTISMENT SETAT!');
          }
        } catch (e) {
          print('❌ Eroare API Google: $e');
        }
      }

      if (currentTask.endTime != null) {
        lastTaskWithLocation = currentTask;
      }
    }

    print('🏁 UseCase terminat.');
    return warnings;
  }
}