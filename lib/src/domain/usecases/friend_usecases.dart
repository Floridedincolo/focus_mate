// filepath: lib/src/domain/usecases/friend_usecases.dart
import '../entities/friendship.dart';
import '../entities/user_profile.dart';
import '../repositories/friend_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SendFriendRequestUseCase
// ─────────────────────────────────────────────────────────────────────────────

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

class AcceptFriendRequestUseCase {
  final FriendRepository _repository;

  const AcceptFriendRequestUseCase(this._repository);

  Future<void> call(String friendshipId) =>
      _repository.acceptFriendRequest(friendshipId);
}

// ─────────────────────────────────────────────────────────────────────────────
// DeclineFriendRequestUseCase
// ─────────────────────────────────────────────────────────────────────────────

class DeclineFriendRequestUseCase {
  final FriendRepository _repository;

  const DeclineFriendRequestUseCase(this._repository);

  Future<void> call(String friendshipId) =>
      _repository.declineFriendRequest(friendshipId);
}

// ─────────────────────────────────────────────────────────────────────────────
// GetFriendsListUseCase
// ─────────────────────────────────────────────────────────────────────────────

class GetFriendsListUseCase {
  final FriendRepository _repository;

  const GetFriendsListUseCase(this._repository);

  Future<List<UserProfile>> call(String currentUserId) =>
      _repository.getFriends(currentUserId);
}

// ─────────────────────────────────────────────────────────────────────────────
// WatchFriendsUseCase
// ─────────────────────────────────────────────────────────────────────────────

class WatchFriendsUseCase {
  final FriendRepository _repository;

  const WatchFriendsUseCase(this._repository);

  Stream<List<UserProfile>> call(String currentUserId) =>
      _repository.watchFriends(currentUserId);
}

// ─────────────────────────────────────────────────────────────────────────────
// WatchIncomingRequestsUseCase
// ─────────────────────────────────────────────────────────────────────────────

class WatchIncomingRequestsUseCase {
  final FriendRepository _repository;

  const WatchIncomingRequestsUseCase(this._repository);

  Stream<List<Friendship>> call(String currentUserId) =>
      _repository.watchIncomingRequests(currentUserId);
}
