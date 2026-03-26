// filepath: lib/src/domain/entities/friendship.dart

/// All possible states a friendship link can be in.
enum FriendshipStatus {
  /// The request has been sent but not yet acted upon.
  pending,

  /// Both users have accepted — they are now friends.
  accepted,

  /// The receiving user declined the request (soft delete, no notification).
  declined,
}

/// Represents a directed friendship link between two users.
///
/// Firestore path: `friendships/{friendshipId}`
class Friendship {
  /// Unique document ID (Firestore auto-ID).
  final String id;

  /// UID of the user who initiated the request.
  final String requesterId;

  /// UID of the user who received the request.
  final String receiverId;

  /// Current state of the relationship.
  final FriendshipStatus status;

  /// When the request was first created.
  final DateTime createdAt;

  /// Last time the status was changed.
  final DateTime updatedAt;

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Friendship copyWith({
    String? id,
    String? requesterId,
    String? receiverId,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Friendship(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convenience: returns true only when the friendship is fully active.
  bool get isAccepted => status == FriendshipStatus.accepted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friendship &&
          other.id == id &&
          other.requesterId == requesterId &&
          other.receiverId == receiverId &&
          other.status == status;

  @override
  int get hashCode => Object.hash(id, requesterId, receiverId, status);

  @override
  String toString() =>
      'Friendship(id: $id, $requesterId → $receiverId, status: ${status.name})';
}
