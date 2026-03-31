
/// DTO that mirrors the `users/{uid}` Firestore document.
class UserProfileDto {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? email;
  final LocationFieldDto? homeLocation;
  final LocationFieldDto? workLocation;

  const UserProfileDto({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.email,
    this.homeLocation,
    this.workLocation,
  });

  factory UserProfileDto.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return UserProfileDto(
      uid: documentId,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      email: data['email'] as String?,
      homeLocation: data['homeLocation'] != null
          ? LocationFieldDto.fromMap(
              data['homeLocation'] as Map<String, dynamic>)
          : null,
      workLocation: data['workLocation'] != null
          ? LocationFieldDto.fromMap(
              data['workLocation'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'displayNameLower': displayName.toLowerCase(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (email != null) 'email': email,
      if (homeLocation != null) 'homeLocation': homeLocation!.toMap(),
      if (workLocation != null) 'workLocation': workLocation!.toMap(),
    };
  }
}

/// Sub-document DTO for home/work location fields inside the user profile.
class LocationFieldDto {
  final String name;
  final double? latitude;
  final double? longitude;

  const LocationFieldDto({
    required this.name,
    this.latitude,
    this.longitude,
  });

  factory LocationFieldDto.fromMap(Map<String, dynamic> map) {
    return LocationFieldDto(
      name: map['name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}

