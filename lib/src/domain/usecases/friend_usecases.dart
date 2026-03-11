// filepath: lib/src/domain/usecases/friend_usecases.dart
import '../entities/friendship.dart';
import '../entities/user_profile.dart';
import '../repositories/friend_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SendFriendRequestUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Sends a friend request from [requesterId] to [receiverId].
///
/// Fails fast when:
/// - Both IDs are the same (cannot add yourself).
/// - A friendship link already exists in Firestore (delegated to repo).
class SendFriendRequestUseCase {
  final FriendRepository _repository;

  const SendFriendRequestUseCase(this._repository);

  Future<void> call({
    required String requesterId,
    required String receiverId,
  }) {
    if (requesterId == receiverId) {
      throw ArgumentError('A user cannot send a friend request to themselves.');
    }
    return _repository.sendFriendRequest(
      requesterId: requesterId,
      receiverId: receiverId,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AcceptFriendRequestUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Accepts a pending [Friendship] identified by [friendshipId].
///
/// The repository is responsible for verifying that the calling user is
/// actually the receiver of the request.
class AcceptFriendRequestUseCase {
  final FriendRepository _repository;

  const AcceptFriendRequestUseCase(this._repository);

  Future<void> call(String friendshipId) =>
      _repository.acceptFriendRequest(friendshipId);
}

// ─────────────────────────────────────────────────────────────────────────────
// DeclineFriendRequestUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Declines (soft-deletes) a pending [Friendship].
class DeclineFriendRequestUseCase {
  final FriendRepository _repository;

  const DeclineFriendRequestUseCase(this._repository);

  Future<void> call(String friendshipId) =>
      _repository.declineFriendRequest(friendshipId);
}

// ─────────────────────────────────────────────────────────────────────────────
// GetFriendsListUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the accepted friends list for [currentUserId] as a one-shot future.
///
/// For real-time updates, use [WatchFriendsUseCase].
class GetFriendsListUseCase {
  final FriendRepository _repository;

  const GetFriendsListUseCase(this._repository);

  Future<List<UserProfile>> call(String currentUserId) =>
      _repository.getFriends(currentUserId);
}

// ─────────────────────────────────────────────────────────────────────────────
// WatchFriendsUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Provides a reactive stream of the current user's accepted friends.
class WatchFriendsUseCase {
  final FriendRepository _repository;

  const WatchFriendsUseCase(this._repository);

  Stream<List<UserProfile>> call(String currentUserId) =>
      _repository.watchFriends(currentUserId);
}

// ─────────────────────────────────────────────────────────────────────────────
// WatchIncomingRequestsUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Streams all pending friend requests *received* by the current user —
/// useful for showing a notification badge in the UI.
class WatchIncomingRequestsUseCase {
  final FriendRepository _repository;

  const WatchIncomingRequestsUseCase(this._repository);

  Stream<List<Friendship>> call(String currentUserId) =>
      _repository.watchIncomingRequests(currentUserId);
}

