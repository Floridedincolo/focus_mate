import '../../domain/entities/user_profile.dart';
import '../../domain/entities/friendship.dart';
import '../dtos/user_profile_dto.dart';
import '../dtos/friendship_dto.dart';

/// Mapper between Friendship / UserProfile domain entities and their DTOs.
class FriendshipMapper {
  // ── UserProfile ─────────────────────────────────────────────────────────

  static UserProfile userProfileToDomain(UserProfileDto dto) {
    return UserProfile(
      uid: dto.uid,
      displayName: dto.displayName,
      photoUrl: dto.photoUrl,
      email: dto.email,
    );
  }

  static UserProfileDto userProfileToDto(UserProfile entity) {
    return UserProfileDto(
      uid: entity.uid,
      displayName: entity.displayName,
      photoUrl: entity.photoUrl,
      email: entity.email,
    );
  }

  static List<UserProfile> userProfileListToDomain(List<UserProfileDto> dtos) {
    return dtos.map(userProfileToDomain).toList();
  }

  // ── Friendship ──────────────────────────────────────────────────────────

  static Friendship friendshipToDomain(FriendshipDto dto) {
    return Friendship(
      id: dto.id,
      requesterId: dto.requesterId,
      receiverId: dto.receiverId,
      status: _parseStatus(dto.status),
      createdAt: dto.createdAt.toDate(),
      updatedAt: dto.updatedAt.toDate(),
    );
  }

  static List<Friendship> friendshipListToDomain(List<FriendshipDto> dtos) {
    return dtos.map(friendshipToDomain).toList();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static FriendshipStatus _parseStatus(String raw) {
    switch (raw) {
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'declined':
        return FriendshipStatus.declined;
      case 'pending':
      default:
        return FriendshipStatus.pending;
    }
  }
}
