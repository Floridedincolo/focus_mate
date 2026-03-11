import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../domain/entities/friendship.dart';
import '../../domain/entities/meeting_proposal.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/errors/domain_errors.dart';
import '../../domain/repositories/friend_repository.dart';
import '../datasources/friend_data_source.dart';
import '../dtos/friendship_dto.dart';
import '../mappers/friendship_mapper.dart';
import '../mappers/meeting_proposal_mapper.dart';
import '../mappers/task_mapper.dart';

/// Concrete Firestore-backed implementation of [FriendRepository].
class FriendRepositoryImpl implements FriendRepository {
  final FriendDataSource _dataSource;

  FriendRepositoryImpl(this._dataSource);

  // ── Discovery ─────────────────────────────────────────────────────────

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    final dto = await _dataSource.getUserProfile(uid);
    return dto == null ? null : FriendshipMapper.userProfileToDomain(dto);
  }

  @override
  Future<List<UserProfile>> searchUsers(
    String query, {
    required String currentUserId,
  }) async {
    final dtos = await _dataSource.searchUsers(query, currentUserId);
    return FriendshipMapper.userProfileListToDomain(dtos);
  }

  // ── Friend Requests ────────────────────────────────────────────────────

  @override
  Future<void> sendFriendRequest({
    required String requesterId,
    required String receiverId,
  }) async {
    // Check for existing link
    final existing =
        await _dataSource.findExistingFriendship(requesterId, receiverId);
    if (existing != null) {
      throw FriendshipAlreadyExistsException(
        'A friendship link already exists between $requesterId and $receiverId '
        '(status: ${existing.status}).',
      );
    }
    await _dataSource.createFriendRequest(
      requesterId: requesterId,
      receiverId: receiverId,
    );
  }

  @override
  Future<void> acceptFriendRequest(String friendshipId) async {
    final dto = await _dataSource.getFriendship(friendshipId);
    if (dto == null) {
      throw FriendshipNotFoundException(
        'Friendship $friendshipId not found.',
      );
    }
    if (dto.status != 'pending') {
      throw FriendshipPermissionException(
        'Cannot accept a friendship that is not pending (current: ${dto.status}).',
      );
    }
    await _dataSource.updateFriendshipStatus(friendshipId, 'accepted');
  }

  @override
  Future<void> declineFriendRequest(String friendshipId) async {
    final dto = await _dataSource.getFriendship(friendshipId);
    if (dto == null) {
      throw FriendshipNotFoundException(
        'Friendship $friendshipId not found.',
      );
    }
    await _dataSource.updateFriendshipStatus(friendshipId, 'declined');
  }

  // ── Friends List ───────────────────────────────────────────────────────

  @override
  Future<List<UserProfile>> getFriends(String currentUserId) async {
    final friendships =
        await _dataSource.getAcceptedFriendships(currentUserId);
    return _resolveProfiles(friendships, currentUserId);
  }

  @override
  Stream<List<UserProfile>> watchFriends(String currentUserId) {
    return _dataSource
        .watchAcceptedFriendships(currentUserId)
        .asyncMap((friendships) =>
            _resolveProfiles(friendships, currentUserId));
  }

  @override
  Stream<List<Friendship>> watchIncomingRequests(String currentUserId) {
    return _dataSource
        .watchIncomingRequests(currentUserId)
        .map(FriendshipMapper.friendshipListToDomain);
  }

  @override
  Stream<List<Friendship>> watchOutgoingRequests(String currentUserId) {
    return _dataSource
        .watchOutgoingRequests(currentUserId)
        .map(FriendshipMapper.friendshipListToDomain);
  }

  // ── Friend Tasks ───────────────────────────────────────────────────────

  @override
  Future<List<Task>> getTasksForUser(String uid) async {
    final dtos = await _dataSource.getTasksForUser(uid);
    return TaskMapper.toDomainList(dtos);
  }

  // ── Meeting Proposals ──────────────────────────────────────────────────

  @override
  Future<String> saveMeetingProposal(MeetingProposal proposal) async {
    final dto = MeetingProposalMapper.toDto(proposal);
    return _dataSource.saveMeetingProposal(dto);
  }

  @override
  Stream<List<MeetingProposal>> watchMeetingProposals(
      String currentUserId) {
    return _dataSource
        .watchMeetingProposals(currentUserId)
        .map(MeetingProposalMapper.toDomainList);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// For each friendship, resolve the *other* user's profile.
  Future<List<UserProfile>> _resolveProfiles(
    List<FriendshipDto> friendships,
    String currentUserId,
  ) async {
    final profiles = <UserProfile>[];
    for (final f in friendships) {
      final otherUid =
          f.requesterId == currentUserId ? f.receiverId : f.requesterId;
      final dto = await _dataSource.getUserProfile(otherUid);
      if (dto != null) {
        profiles.add(FriendshipMapper.userProfileToDomain(dto));
      } else {
        // Fallback: show a placeholder for deleted / missing profiles
        profiles.add(UserProfile(
          uid: otherUid,
          displayName: 'Unknown user',
        ));
        if (kDebugMode) {
          debugPrint('⚠️ Missing profile for $otherUid');
        }
      }
    }
    return profiles;
  }
}

