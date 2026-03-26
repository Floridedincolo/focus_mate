import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/service_locator.dart';
import '../../domain/entities/meeting_location.dart';
import '../../domain/repositories/user_location_repository.dart';

/// Exposes the singleton [UserLocationRepository] from GetIt.
final userLocationRepoProvider = Provider<UserLocationRepository>(
  (_) => getIt<UserLocationRepository>(),
);

/// Whether the user has completed the onboarding location setup.
final hasCompletedSetupProvider = FutureProvider<bool>((ref) {
  return ref.watch(userLocationRepoProvider).hasCompletedSetup();
});

/// Returns `(home, work)` locations from SharedPreferences.
final userLocationsProvider =
    FutureProvider<(MeetingLocation?, MeetingLocation?)>((ref) {
  return ref.watch(userLocationRepoProvider).getUserLocations();
});
