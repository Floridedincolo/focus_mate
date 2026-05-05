import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/meeting_location.dart';

/// Simple local service that persists a history of locations used in tasks.
/// Each entry stores name + latitude + longitude.
class LocationHistoryService {
  static const _key = 'location_history';
  static const _maxEntries = 20;

  /// Returns all saved locations (most recent first).
  Future<List<MeetingLocation>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((json) {
          try {
            final map = jsonDecode(json) as Map<String, dynamic>;
            return MeetingLocation(
              name: map['name'] as String,
              latitude: (map['lat'] as num?)?.toDouble(),
              longitude: (map['lng'] as num?)?.toDouble(),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<MeetingLocation>()
        .toList();
  }

  /// Saves a location to history. Skips if no coordinates.
  /// Deduplicates by name (case-insensitive) and keeps most recent first.
  Future<void> saveLocation(MeetingLocation location) async {
    if (!location.hasCoordinates) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    // Remove duplicates by name
    raw.removeWhere((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return (map['name'] as String).toLowerCase() ==
            location.name.toLowerCase();
      } catch (_) {
        return false;
      }
    });

    // Add to front (most recent first)
    raw.insert(
      0,
      jsonEncode({
        'name': location.name,
        'lat': location.latitude,
        'lng': location.longitude,
      }),
    );

    // Trim to max
    if (raw.length > _maxEntries) {
      raw.removeRange(_maxEntries, raw.length);
    }

    await prefs.setStringList(_key, raw);
  }

  /// Removes a location from history by name.
  Future<void> removeLocation(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return (map['name'] as String).toLowerCase() == name.toLowerCase();
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_key, raw);
  }
}
