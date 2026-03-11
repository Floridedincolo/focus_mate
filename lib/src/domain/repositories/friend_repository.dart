// filepath: lib/src/domain/repositories/friend_repository.dart
import '../entities/friendship.dart';
import '../entities/meeting_proposal.dart';
import '../entities/task.dart';
import '../entities/user_profile.dart';

/// Abstracts all Firestore operations related to friendships and user profiles.
///
/// **Firestore topology assumed by this contract:**
/// ```
/// users/
///   {uid}/                    ← public profile (UserProfile fields)
///     displayName: "Teodor"
///     photoUrl:    "https://..."
///     email:       "t@example.com"   ← optional
///
/// friendships/
///   {friendshipId}/           ← see [Friendship] for field details
/// ```
///
/// Implementations live in `lib/src/data/repositories/`.
abstract class FriendRepository {
  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Looks up a [UserProfile] by their Firebase Auth [uid].
  /// Returns `null` when the user does not exist or has no public profile.
  Future<UserProfile?> getUserProfile(String uid);

  /// Searches for users whose `displayName` contains [query] (case-insensitive
  /// on the client; the Firestore query uses a range filter on the raw value).
  ///
  /// The [currentUserId]'s own profile is excluded from results.
  Future<List<UserProfile>> searchUsers(String query, {required String currentUserId});

  // ── Friend Requests ────────────────────────────────────────────────────────

  /// Creates a new [Friendship] document with status [FriendshipStatus.pending].
  ///
  /// Throws [FriendshipAlreadyExistsException] if a link (in any direction)
  /// already exists between [requesterId] and [receiverId].
  Future<void> sendFriendRequest({
    required String requesterId,
    required String receiverId,
  });

  /// Transitions the [Friendship.status] to [FriendshipStatus.accepted].
  ///
  /// Throws [FriendshipNotFoundException] if [friendshipId] does not exist.
  /// Throws [FriendshipPermissionException] if the caller is not the receiver.
  Future<void> acceptFriendRequest(String friendshipId);

  /// Transitions the [Friendship.status] to [FriendshipStatus.declined]
  /// (soft delete — document is kept for audit purposes).
  Future<void> declineFriendRequest(String friendshipId);

  // ── Friends List ───────────────────────────────────────────────────────────

  /// Returns all [UserProfile]s for which an `accepted` [Friendship] exists
  /// involving [currentUserId].
  ///
  /// This is a one-shot future; use [watchFriends] for real-time updates.
  Future<List<UserProfile>> getFriends(String currentUserId);

  /// Reactive stream of the current user's accepted friends list.
  Stream<List<UserProfile>> watchFriends(String currentUserId);

  /// Returns pending requests *received* by [currentUserId].
  Stream<List<Friendship>> watchIncomingRequests(String currentUserId);

  /// Returns pending requests *sent* by [currentUserId].
  Stream<List<Friendship>> watchOutgoingRequests(String currentUserId);

  // ── Friend Tasks ──────────────────────────────────────────────────────────

  /// Returns the task list for a given user (used for meeting suggestions).
  /// Requires that [uid] is an accepted friend of the calling user.
  Future<List<Task>> getTasksForUser(String uid);

  // ── Meeting Proposals ─────────────────────────────────────────────────

  /// Saves a meeting proposal to Firestore. Returns the document ID.
  Future<String> saveMeetingProposal(MeetingProposal proposal);

  /// Real-time stream of meeting proposals where [currentUserId] is a
  /// group member, ordered by start time descending.
  Stream<List<MeetingProposal>> watchMeetingProposals(String currentUserId);
}

