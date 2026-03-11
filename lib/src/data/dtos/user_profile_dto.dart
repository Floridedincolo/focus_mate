
/// DTO that mirrors the `users/{uid}` Firestore document.
class UserProfileDto {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? email;

  const UserProfileDto({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.email,
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'displayNameLower': displayName.toLowerCase(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (email != null) 'email': email,
    };
  }
}

