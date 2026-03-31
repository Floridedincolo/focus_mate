import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../domain/entities/autocomplete_prediction.dart';
import '../../../domain/entities/meeting_location.dart';
import '../../../domain/errors/domain_errors.dart';
import '../location_search_service.dart';

/// Real Google Places API implementation of [LocationSearchService].
///
/// ### Safety Limiter
/// To prevent accidental cost overruns during development, this service
/// includes a hard cap of [_maxRequests] API calls per app session.
/// Once exceeded, it throws a [PlacesRateLimitException].
class GooglePlacesSearchService implements LocationSearchService {
  // ── Rate Limiter ──────────────────────────────────────────────────────

  static const int _maxRequests = 20;
  static int _requestCount = 0;
  static int get requestCount => _requestCount;
  static void resetCounter() => _requestCount = 0;

  // ── Constants ─────────────────────────────────────────────────────────

  static const _baseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  static const _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  static const _placeDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  static const _defaultRadiusMetres = 1500;
  static const _timeout = Duration(seconds: 10);

  // ── Core method ───────────────────────────────────────────────────────

  @override
  Future<MeetingLocation> findNearestPlace({
    required double latitude,
    required double longitude,
    required String keyword,
    int radiusMetres = _defaultRadiusMetres,
  }) async {
    if (_requestCount >= _maxRequests) {
      throw PlacesRateLimitException(
        'Safety limit reached: $_maxRequests Places API requests per session. '
        'Restart the app to reset, or increase _maxRequests.',
      );
    }

    final apiKey = _requireApiKey();

    final type = _keywordToType(keyword);
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'location': '$latitude,$longitude',
      'radius': '$radiusMetres',
      'keyword': keyword,
      if (type != null) 'type': type,
      'key': apiKey,
    });

    _requestCount++;
    if (kDebugMode) {
      debugPrint(
        '📍 Places API request #$_requestCount: '
        'keyword="$keyword" near ($latitude, $longitude)',
      );
    }

    final http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } catch (e) {
      throw AiSuggestionException(
        'Google Places API network error: $e',
        e is Exception ? e : null,
      );
    }

    if (response.statusCode != 200) {
      throw AiSuggestionException(
        'Google Places API returned status ${response.statusCode}: '
        '${response.body.substring(0, response.body.length.clamp(0, 300))}',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw AiSuggestionException(
        'Failed to parse Places API JSON: $e',
      );
    }

    final status = json['status'] as String? ?? '';
    if (status != 'OK') {
      if (kDebugMode) {
        debugPrint('⚠️ Places API status: $status');
      }
      return MeetingLocation(
        name: _capitalize(keyword),
        latitude: latitude,
        longitude: longitude,
      );
    }

    final results = json['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) {
      return MeetingLocation(
        name: _capitalize(keyword),
        latitude: latitude,
        longitude: longitude,
      );
    }

    // Filter out non-establishment results (streets, routes, etc.)
    // and pick the closest one to the requested midpoint.
    const excludedTypes = {'route', 'street_address', 'geocode', 'locality',
        'political', 'sublocality', 'neighborhood'};

    Map<String, dynamic>? bestPlace;
    double bestDist = double.infinity;

    for (final r in results) {
      final place = r as Map<String, dynamic>;
      final types = (place['types'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toSet() ??
          {};

      // Skip if it's a street/route/area, not an actual place.
      if (types.any(excludedTypes.contains) &&
          !types.contains('establishment')) {
        if (kDebugMode) {
          debugPrint('⏭️ Skipping non-place: "${place['name']}" types=$types');
        }
        continue;
      }

      final geometry = place['geometry'] as Map<String, dynamic>?;
      final loc = geometry?['location'] as Map<String, dynamic>?;
      final pLat = (loc?['lat'] as num?)?.toDouble();
      final pLng = (loc?['lng'] as num?)?.toDouble();
      if (pLat == null || pLng == null) continue;

      // Simple Euclidean distance (fine for short ranges).
      final dist = (pLat - latitude) * (pLat - latitude) +
          (pLng - longitude) * (pLng - longitude);
      if (dist < bestDist) {
        bestDist = dist;
        bestPlace = place;
      }
    }

    // If all results were filtered out, fall back to generic keyword name.
    if (bestPlace == null) {
      if (kDebugMode) {
        debugPrint('⚠️ All ${results.length} results filtered out for "$keyword"');
      }
      return MeetingLocation(
        name: _capitalize(keyword),
        latitude: latitude,
        longitude: longitude,
      );
    }

    final name = bestPlace['name'] as String? ?? _capitalize(keyword);
    final geometry = bestPlace['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    final placeLat = (loc?['lat'] as num?)?.toDouble() ?? latitude;
    final placeLng = (loc?['lng'] as num?)?.toDouble() ?? longitude;

    if (kDebugMode) {
      debugPrint('✅ Places API found: "$name" at ($placeLat, $placeLng)');
    }

    return MeetingLocation(
      name: name,
      latitude: placeLat,
      longitude: placeLng,
    );
  }

  // ── Autocomplete ───────────────────────────────────────────────────────

  @override
  Future<List<AutocompletePrediction>> autocompletePlaces({
    required String input,
    String? sessionToken,
    double? userLat,
    double? userLng,
    String countryCode = 'ro',
  }) async {
    if (input.trim().isEmpty) return const [];

    if (_requestCount >= _maxRequests) {
      throw PlacesRateLimitException(
        'Safety limit reached: $_maxRequests Places API requests per session.',
      );
    }

    final apiKey = _requireApiKey();

    final params = <String, String>{
      'input': input,
      'key': apiKey,
      'components': 'country:$countryCode',
    };
    if (sessionToken != null) params['sessiontoken'] = sessionToken;
    if (userLat != null && userLng != null) {
      params['location'] = '$userLat,$userLng';
      params['radius'] = '50000';
    }

    final uri =
        Uri.parse(_autocompleteUrl).replace(queryParameters: params);

    _requestCount++;
    if (kDebugMode) {
      debugPrint(
        '🔍 Autocomplete #$_requestCount: "$input" '
        '(country=$countryCode, biased=${userLat != null})',
      );
    }

    final http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Autocomplete network error: $e');
      return const [];
    }

    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') return const [];

    final predictions = json['predictions'] as List<dynamic>? ?? [];
    return predictions.map((p) {
      final pred = p as Map<String, dynamic>;
      final structured =
          pred['structured_formatting'] as Map<String, dynamic>? ?? {};
      return AutocompletePrediction(
        placeId: pred['place_id'] as String? ?? '',
        mainText: structured['main_text'] as String? ?? '',
        secondaryText: structured['secondary_text'] as String? ?? '',
        fullText: pred['description'] as String? ?? '',
      );
    }).toList();
  }

  // ── Place Details ─────────────────────────────────────────────────────

  @override
  Future<MeetingLocation?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
  }) async {
    if (placeId.isEmpty) return null;

    if (_requestCount >= _maxRequests) {
      throw PlacesRateLimitException(
        'Safety limit reached: $_maxRequests Places API requests per session.',
      );
    }

    final apiKey = _requireApiKey();

    final params = <String, String>{
      'place_id': placeId,
      'fields': 'name,geometry',
      'key': apiKey,
    };
    if (sessionToken != null) params['sessiontoken'] = sessionToken;

    final uri =
        Uri.parse(_placeDetailsUrl).replace(queryParameters: params);

    _requestCount++;
    if (kDebugMode) {
      debugPrint('📌 Place Details #$_requestCount: placeId=$placeId');
    }

    final http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Place Details network error: $e');
      return null;
    }

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if ((json['status'] as String?) != 'OK') return null;

    final result = json['result'] as Map<String, dynamic>? ?? {};
    final name = result['name'] as String?;
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();

    if (name == null) return null;

    if (kDebugMode) {
      debugPrint('✅ Place Details: "$name" at ($lat, $lng)');
    }

    return MeetingLocation(name: name, latitude: lat, longitude: lng);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _requireApiKey() {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw AiSuggestionException(
        'GOOGLE_PLACES_API_KEY is missing from .env file.',
      );
    }
    return apiKey;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Maps a keyword to a Google Places [type] to filter out non-place results
  /// (e.g. streets). Returns `null` if no specific type applies.
  static String? _keywordToType(String keyword) {
    const map = {
      'cafe': 'cafe',
      'coffee': 'cafe',
      'restaurant': 'restaurant',
      'bar': 'bar',
      'park': 'park',
      'library': 'library',
      'gym': 'gym',
      'coworking': 'establishment',
    };
    return map[keyword.trim().toLowerCase()];
  }
}
