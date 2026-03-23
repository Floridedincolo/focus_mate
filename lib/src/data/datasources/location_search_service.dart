import '../../domain/entities/autocomplete_prediction.dart';
import '../../domain/entities/meeting_location.dart';

/// Abstract contract for looking up real places via Google Places (or mock).
///
/// Provides three capabilities:
/// 1. **Nearby Search** — find a place near a GPS point by keyword
///    (used by the Gemini → Places pipeline).
/// 2. **Autocomplete** — type-ahead predictions for a text query
///    (used by the location field in Add/Edit Task).
/// 3. **Place Details** — resolve a Place ID to a name + lat/lng
///    (called after the user taps an autocomplete suggestion).
///
/// Implementations:
/// - [MockLocationSearchService]  — hardcoded results for offline dev
/// - [GooglePlacesSearchService]  — real Google Places API
abstract class LocationSearchService {
  /// Searches for a real place near ([latitude], [longitude]) matching
  /// [keyword] (e.g. "cafe", "restaurant", "library", "park").
  ///
  /// Returns a [MeetingLocation] with the place's real name and coordinates.
  Future<MeetingLocation> findNearestPlace({
    required double latitude,
    required double longitude,
    required String keyword,
  });

  /// Returns autocomplete predictions for [input].
  ///
  /// Optional parameters:
  /// - [sessionToken] — groups autocomplete + details into one billing session.
  /// - [userLat], [userLng] — bias results towards the user's location.
  /// - [countryCode] — restrict to a country (default: `'ro'`).
  Future<List<AutocompletePrediction>> autocompletePlaces({
    required String input,
    String? sessionToken,
    double? userLat,
    double? userLng,
    String countryCode = 'ro',
  });

  /// Fetches the full details (name + coordinates) for a [placeId].
  ///
  /// Pass the same [sessionToken] used during autocomplete to combine
  /// them into a single billing session.
  Future<MeetingLocation?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
  });
}

