// filepath: lib/src/domain/repositories/friend_repository.dart
import '../entities/friendship.dart';
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';
import '../entities/user_profile.dart';

/// Abstracts all Firestore operations related to friendships and user profiles.
abstract class FriendRepository {
  // ── Discovery ─────────────────────────────────────────────────────────────

  Future<UserProfile?> getUserProfile(String uid);

  Future<List<UserProfile>> searchUsers(String query, {required String currentUserId});

  // ── Friend Requests ────────────────────────────────────────────────────────

  Future<void> sendFriendRequest({
    required String requesterId,
    required String receiverId,
  });

  Future<void> acceptFriendRequest(String friendshipId);

  Future<void> declineFriendRequest(String friendshipId);

  // ── Friends List ───────────────────────────────────────────────────────────

  Future<List<UserProfile>> getFriends(String currentUserId);

  Stream<List<UserProfile>> watchFriends(String currentUserId);

  Stream<List<Friendship>> watchIncomingRequests(String currentUserId);

  Stream<List<Friendship>> watchOutgoingRequests(String currentUserId);

  // ── Friend Tasks ──────────────────────────────────────────────────────────

  Future<List<Task>> getTasksForUser(String uid);

  // ── Meeting Proposals ─────────────────────────────────────────────────

  Future<String> saveMeetingProposal(MeetingProposal proposal);

  Stream<List<MeetingProposal>> watchMeetingProposals(String currentUserId);
}
