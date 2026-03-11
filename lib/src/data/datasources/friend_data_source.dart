import '../dtos/friendship_dto.dart';
import '../dtos/meeting_proposal_dto.dart';
import '../dtos/task_dto.dart' show TaskDTO;
import '../dtos/user_profile_dto.dart';

/// Abstract contract for Firestore operations on users and friendships.
///
/// Implementations live in `implementations/`.
abstract class FriendDataSource {
  // ── User Profiles ───────────────────────────────────────────────────────

  /// Fetches the public profile for [uid].
  /// Returns `null` when no document exists at `users/{uid}`.
  Future<UserProfileDto?> getUserProfile(String uid);

  /// Searches users whose `displayName` starts with [query] (Firestore range).
  /// Excludes [currentUserId] from results.
  Future<List<UserProfileDto>> searchUsers(String query, String currentUserId);

  /// Creates or updates the public profile for [uid].
  Future<void> upsertUserProfile(UserProfileDto dto);

  // ── Friend Requests ─────────────────────────────────────────────────────

  /// Creates a new friendship document with status `pending`.
  /// Returns the auto-generated Firestore document ID.
  Future<String> createFriendRequest({
    required String requesterId,
    required String receiverId,
  });

  /// Updates the `status` and `updatedAt` fields on an existing friendship.
  Future<void> updateFriendshipStatus(String friendshipId, String newStatus);

  /// Checks whether a friendship link (in any direction, any status other than
  /// `declined`) already exists between [userA] and [userB].
  Future<FriendshipDto?> findExistingFriendship(String userA, String userB);

  /// Returns the friendship document by ID, or `null` if missing.
  Future<FriendshipDto?> getFriendship(String friendshipId);

  // ── Friends List ────────────────────────────────────────────────────────

  /// One-shot: returns all friendship documents where [uid] is a participant
  /// and status == `accepted`.
  Future<List<FriendshipDto>> getAcceptedFriendships(String uid);

  /// Real-time stream of accepted friendships involving [uid].
  Stream<List<FriendshipDto>> watchAcceptedFriendships(String uid);

  /// Real-time stream of pending requests *received* by [uid].
  Stream<List<FriendshipDto>> watchIncomingRequests(String uid);

  /// Real-time stream of pending requests *sent* by [uid].
  Stream<List<FriendshipDto>> watchOutgoingRequests(String uid);

  // ── Friend Tasks ────────────────────────────────────────────────────────

  /// Fetches a user's tasks for use in meeting suggestions.
  /// Returns the raw task DTOs from `users/{uid}/tasks`.
  Future<List<TaskDTO>> getTasksForUser(String uid);

  // ── Meeting Proposals ──────────────────────────────────────────────────

  /// Saves a meeting proposal to Firestore. Returns the document ID.
  Future<String> saveMeetingProposal(MeetingProposalDto dto);

  /// Real-time stream of meeting proposals where [uid] is a participant,
  /// ordered by startTime descending.
  Stream<List<MeetingProposalDto>> watchMeetingProposals(String uid);
}

