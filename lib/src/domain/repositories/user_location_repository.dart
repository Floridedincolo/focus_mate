import '../entities/meeting_location.dart';

/// Stores and retrieves the user's default home & work locations.
abstract class UserLocationRepository {
  /// Persists the user's home and work locations.
  Future<void> saveUserLocations({
    MeetingLocation? home,
    MeetingLocation? work,
  });

  /// Returns `(home, work)` — either may be `null` if not yet set.
  Future<(MeetingLocation?, MeetingLocation?)> getUserLocations();

  /// Whether the user has completed the initial location setup.
  Future<bool> hasCompletedSetup();

  /// Marks the onboarding setup as complete.
  Future<void> markSetupComplete();
}

