import '../../domain/entities/meeting_location.dart';

/// Abstract contract for computing transit time between two locations.
///
/// Implementations:
/// - [GoogleTransitRouteService] — real Google Routes API with local caching
abstract class TransitRouteService {
  /// Returns the estimated travel time in **minutes** between [origin] and
  /// [destination] using [mode] (`'DRIVE'`, `'WALK'`, or `'TRANSIT'`).
  ///
  /// Results are cached locally so repeated queries for the same pair
  /// (regardless of direction) hit the cache instead of the API.
  ///
  /// Returns `null` if either location lacks coordinates or the API fails.
  Future<int?> getTransitTimeMinutes({
    required MeetingLocation origin,
    required MeetingLocation destination,
    String mode = 'DRIVE',
  });

  /// Clears the local transit cache. Useful for testing.
  Future<void> clearCache();
}
