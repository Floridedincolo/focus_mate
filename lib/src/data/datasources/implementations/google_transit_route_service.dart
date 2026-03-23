import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/meeting_location.dart';
import '../transit_route_service.dart';

/// Google Routes API (V2) implementation of [TransitRouteService].
///
/// ### Fallback Strategy
/// 1. Check **local cache** (SharedPreferences).
/// 2. Call **Google Routes API V2** for real traffic-aware duration.
/// 3. If the API call fails (403, network error, rate-limited, etc.),
///    fall back to a **Haversine straight-line estimate** so the user
///    still gets a warning instead of silent failure.
///
/// ### Caching
/// Every origin→destination+mode pair is cached under a deterministic key
/// built from rounded coordinates (5 decimal places ≈ 1 m precision).
///
/// ### Safety Limiter
/// A per-session hard cap ([_maxRequests]) prevents accidental cost overruns.
class GoogleTransitRouteService implements TransitRouteService {
  // ── Rate Limiter ──────────────────────────────────────────────────────

  static const int _maxRequests = 50;
  static int _requestCount = 0;
  static int get requestCount => _requestCount;
  static void resetCounter() => _requestCount = 0;

  // ── Constants ─────────────────────────────────────────────────────────

  static const _routesUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  static const _timeout = Duration(seconds: 10);

  /// SharedPreferences key prefix for transit cache entries.
  /// Bump the version (v2, v3…) whenever the caching semantics change
  /// (e.g. parking overhead added) to auto-invalidate stale entries.
  static const _cachePrefix = 'transit_v2_';

  /// Average driving speed in km/h used for Haversine fallback.
  static const _avgDriveKmh = 30.0;

  /// Average walking speed in km/h used for Haversine fallback.
  static const _avgWalkKmh = 5.0;

  /// Average public-transport speed in km/h used for Haversine fallback.
  static const _avgTransitKmh = 20.0;

  /// Detour multiplier — straight-line distances are multiplied by this
  /// to approximate real-road distances (roads are rarely straight).
  static const _detourFactor = 1.4;

  /// Extra minutes added to driving estimates to account for parking,
  /// walking to/from the car, etc.
  static const parkingOverheadMinutes = 5;

  // ── Core method ───────────────────────────────────────────────────────

  @override
  Future<int?> getTransitTimeMinutes({
    required MeetingLocation origin,
    required MeetingLocation destination,
    String mode = 'DRIVE',
  }) async {
    // Guard: both locations must have coordinates.
    if (!origin.hasCoordinates || !destination.hasCoordinates) return null;

    final cacheKey = _buildCacheKey(origin, destination, mode);

    // 1. Check local cache first.
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt('$_cachePrefix$cacheKey');
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('🗺️ Transit cache HIT: $cacheKey → ${cached}min');
        }
        return cached;
      }
    } catch (_) {
      // SharedPreferences error — proceed to API.
    }

    // 2. Try Google Routes API V2.
    final apiMinutes = await _fetchFromRoutesApi(origin, destination, mode);
    if (apiMinutes != null) {
      // Cache the successful API result.
      await _cacheResult(cacheKey, apiMinutes);
      return apiMinutes;
    }

    // 3. Fallback: Haversine estimate.
    final fallback = _haversineEstimate(origin, destination, mode);
    if (kDebugMode) {
      debugPrint(
        '🗺️ Haversine fallback → ${fallback}min ($mode)',
      );
    }
    // Don't cache the fallback — next time the API might be available.
    return fallback;
  }

  // ── Routes API call ───────────────────────────────────────────────────

  Future<int?> _fetchFromRoutesApi(
    MeetingLocation origin,
    MeetingLocation destination,
    String mode,
  ) async {
    // Rate limiter check.
    if (_requestCount >= _maxRequests) {
      if (kDebugMode) {
        debugPrint(
          '🗺️ Transit rate limit reached ($_requestCount/$_maxRequests).',
        );
      }
      return null;
    }

    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) debugPrint('🗺️ No API key found for Routes API');
      return null;
    }

    _requestCount++;

    try {
      final body = jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': mode.toUpperCase(),
        'routingPreference':
            mode.toUpperCase() == 'DRIVE'
                ? 'TRAFFIC_AWARE'
                : 'ROUTING_PREFERENCE_UNSPECIFIED',
      });

      final response = await http
          .post(
            Uri.parse(_routesUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'routes.duration',
            },
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            '🗺️ Routes API error ${response.statusCode}: ${response.body}',
          );
        }
        return null; // Will fall through to Haversine.
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final durationStr =
          (routes[0] as Map<String, dynamic>)['duration'] as String?;
      if (durationStr == null) return null;

      // Parse "900s" → 900 → 15 minutes.
      final seconds = int.tryParse(durationStr.replaceAll('s', ''));
      if (seconds == null) return null;

      // Minimum 1 minute — even a "0s" API response means you still
      // need some time to physically get there.
      final minutes = (seconds / 60).ceil().clamp(1, 99999);

      if (kDebugMode) {
        debugPrint(
          '🗺️ Routes API → ${minutes}min ($mode) '
          '[request #$_requestCount/$_maxRequests]',
        );
      }

      return minutes;
    } catch (e) {
      if (kDebugMode) debugPrint('🗺️ Routes API exception: $e');
      return null; // Will fall through to Haversine.
    }
  }

  // ── Haversine fallback ────────────────────────────────────────────────

  /// Estimates travel time using the Haversine great-circle distance,
  /// a detour multiplier, and an average speed for the given mode.
  int _haversineEstimate(
    MeetingLocation origin,
    MeetingLocation destination,
    String mode,
  ) {
    final distKm =
        haversineKm(origin.latitude!, origin.longitude!, destination.latitude!, destination.longitude!);
    final roadKm = distKm * _detourFactor;
    final modeUpper = mode.toUpperCase();
    final speed = modeUpper == 'WALK'
        ? _avgWalkKmh
        : modeUpper == 'TRANSIT'
            ? _avgTransitKmh
            : _avgDriveKmh;
    final minutes = (roadKm / speed * 60).ceil();
    // Minimum 1 minute even for very short distances.
    return minutes < 1 ? 1 : minutes;
  }

  /// Haversine formula — returns straight-line distance in kilometres.
  /// Public so callers (e.g. add_task) can check distance thresholds.
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  // ── Cache helpers ─────────────────────────────────────────────────────

  Future<void> _cacheResult(String cacheKey, int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_cachePrefix$cacheKey', minutes);
    } catch (_) {
      // Caching failed — non-critical.
    }
  }

  @override
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) =>
            k.startsWith(_cachePrefix) || k.startsWith('transit_cache_'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    if (kDebugMode) {
      debugPrint('🗺️ Cleared ${keys.length} transit cache entries');
    }
  }

  // ── Key builder ───────────────────────────────────────────────────────

  /// Builds a deterministic cache key from two locations + mode.
  String _buildCacheKey(
    MeetingLocation origin,
    MeetingLocation destination,
    String mode,
  ) {
    final oLat = origin.latitude!.toStringAsFixed(5);
    final oLng = origin.longitude!.toStringAsFixed(5);
    final dLat = destination.latitude!.toStringAsFixed(5);
    final dLng = destination.longitude!.toStringAsFixed(5);
    return '${oLat}_${oLng}_${dLat}_${dLng}_${mode.toUpperCase()}';
  }
}

