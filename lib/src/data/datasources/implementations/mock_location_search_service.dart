import '../../../domain/entities/autocomplete_prediction.dart';
import '../../../domain/entities/meeting_location.dart';
import '../location_search_service.dart';

/// Mock implementation of [LocationSearchService] for offline development.
///
/// Simulates a 1-second network delay, then returns a hardcoded place
/// based on the [keyword]. Replace with a real Google Places / Mapbox
/// implementation once you have an API key.
class MockLocationSearchService implements LocationSearchService {
  /// Hardcoded places per keyword category, located around Iași, Romania.
  static const _mockPlaces = <String, _MockPlace>{
    'cafe': _MockPlace('Starbucks Palas', 47.1557, 27.5886),
    'coffee': _MockPlace('Narcoffee Roasters', 47.1585, 27.5870),
    'restaurant': _MockPlace('Terasa La Castel', 47.1568, 27.5895),
    'park': _MockPlace('Parcul Copou', 47.1745, 27.5672),
    'library': _MockPlace('Biblioteca Centrală Universitară', 47.1737, 27.5748),
    'bar': _MockPlace('Pio Bistro', 47.1580, 27.5890),
    'gym': _MockPlace('WorldClass Palas', 47.1555, 27.5880),
    'coworking': _MockPlace('Hub Iași', 47.1610, 27.5850),
  };

  /// Fallback when the keyword doesn't match any known category.
  static const _fallback = _MockPlace('Palas Mall', 47.1560, 27.5885);

  @override
  Future<MeetingLocation> findNearestPlace({
    required double latitude,
    required double longitude,
    required String keyword,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    final key = keyword.trim().toLowerCase();
    final place = _mockPlaces.entries
        .where((e) => key.contains(e.key) || e.key.contains(key))
        .map((e) => e.value)
        .firstOrNull ?? _fallback;

    return MeetingLocation(
      name: place.name,
      latitude: place.lat,
      longitude: place.lng,
    );
  }

  @override
  Future<List<AutocompletePrediction>> autocompletePlaces({
    required String input,
    String? sessionToken,
    double? userLat,
    double? userLng,
    String countryCode = 'ro',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (input.trim().isEmpty) return const [];

    final lower = input.toLowerCase();
    return _mockPlaces.entries
        .where((e) => e.value.name.toLowerCase().contains(lower))
        .map((e) => AutocompletePrediction(
              placeId: 'mock_${e.key}',
              mainText: e.value.name,
              secondaryText: 'Iași, Romania',
              fullText: '${e.value.name}, Iași, Romania',
            ))
        .toList();
  }

  @override
  Future<MeetingLocation?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final key = placeId.replaceFirst('mock_', '');
    final place = _mockPlaces[key];
    if (place == null) return null;
    return MeetingLocation(
      name: place.name,
      latitude: place.lat,
      longitude: place.lng,
    );
  }
}

class _MockPlace {
  final String name;
  final double lat;
  final double lng;
  const _MockPlace(this.name, this.lat, this.lng);
}

