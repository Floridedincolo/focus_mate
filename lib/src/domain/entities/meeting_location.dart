// filepath: lib/src/domain/entities/meeting_location.dart

/// A physical (or virtual) location associated with a meeting proposal.
///
/// Coordinates are intentionally **optional** so the entity can be used at
/// every stage of the pipeline:
///
/// | Stage                  | name        | lat/lng       |
/// |------------------------|-------------|---------------|
/// | Algorithmic suggestion | "TBD"       | null / null   |
/// | AI suggestion          | "Cafenea"   | null / null   |
/// | User-confirmed spot    | "Boema"     | 46.77 / 23.59 |
/// | Future transit calc    | any         | required      |
///
/// This mirrors the `MeetingLocation` sub-document inside a `meetingProposals`
/// Firestore document.
class MeetingLocation {
  /// Human-readable label shown in the UI (e.g. "Cafenea", "Providența").
  final String name;

  /// WGS-84 latitude — null until the user pins an exact spot.
  final double? latitude;

  /// WGS-84 longitude — null until the user pins an exact spot.
  final double? longitude;

  const MeetingLocation({
    required this.name,
    this.latitude,
    this.longitude,
  });

  /// Convenience constructor for a fully unresolved location (algorithmic path).
  const MeetingLocation.tbd()
      : name = 'Location TBD',
        latitude = null,
        longitude = null;

  /// True when coordinates are available for transit-time calculations.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Creates a copy. Pass [clearLatitude] / [clearLongitude] = true to reset
  /// coordinates to null (since Dart `copyWith` can't distinguish "not passed"
  /// from "passed null").
  MeetingLocation copyWith({
    String? name,
    double? latitude,
    double? longitude,
    bool clearLatitude = false,
    bool clearLongitude = false,
  }) {
    return MeetingLocation(
      name: name ?? this.name,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingLocation &&
          other.name == name &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, latitude, longitude);

  @override
  String toString() => hasCoordinates
      ? 'MeetingLocation($name @ $latitude,$longitude)'
      : 'MeetingLocation($name)';
}

