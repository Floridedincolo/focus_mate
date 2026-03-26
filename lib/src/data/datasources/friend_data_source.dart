import '../dtos/friendship_dto.dart';
import '../dtos/meeting_proposal_dto.dart';
import '../dtos/task_dto.dart' show TaskDTO;
import '../dtos/user_profile_dto.dart';

/// Abstract contract for Firestore operations on users and friendships.
abstract class FriendDataSource {
  // ── User Profiles ───────────────────────────────────────────────────────

  Future<UserProfileDto?> getUserProfile(String uid);

  Future<List<UserProfileDto>> searchUsers(String query, String currentUserId);

  Future<void> upsertUserProfile(UserProfileDto dto);

  // ── Friend Requests ─────────────────────────────────────────────────────

  Future<String> createFriendRequest({
    required String requesterId,
    required String receiverId,
  });

  Future<void> updateFriendshipStatus(String friendshipId, String newStatus);

  Future<FriendshipDto?> findExistingFriendship(String userA, String userB);

  Future<FriendshipDto?> getFriendship(String friendshipId);

  // ── Friends List ────────────────────────────────────────────────────────

  Future<List<FriendshipDto>> getAcceptedFriendships(String uid);

  Stream<List<FriendshipDto>> watchAcceptedFriendships(String uid);

  Stream<List<FriendshipDto>> watchIncomingRequests(String uid);

  Stream<List<FriendshipDto>> watchOutgoingRequests(String uid);

  // ── Friend Tasks ────────────────────────────────────────────────────────

  Future<List<TaskDTO>> getTasksForUser(String uid);

  // ── Meeting Proposals ──────────────────────────────────────────────────

  Future<String> saveMeetingProposal(MeetingProposalDto dto);

  Stream<List<MeetingProposalDto>> watchMeetingProposals(String uid);
}
