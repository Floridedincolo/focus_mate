import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../dtos/friendship_dto.dart';
import '../../dtos/meeting_proposal_dto.dart';
import '../../dtos/task_dto.dart' show TaskDTO;
import '../../dtos/user_profile_dto.dart';
import '../friend_data_source.dart';

/// Firestore implementation of [FriendDataSource].
///
/// **Firestore composite indexes required:**
/// 1. `friendships`: `receiverId` ASC, `status` ASC
/// 2. `friendships`: `requesterId` ASC, `status` ASC
class FirestoreFriendDataSource implements FriendDataSource {
  final FirebaseFirestore _firestore;

  FirestoreFriendDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _friendshipsCol =>
      _firestore.collection('friendships');

  CollectionReference<Map<String, dynamic>> get _meetingProposalsCol =>
      _firestore.collection('meetingProposals');

  // ── User Profiles ───────────────────────────────────────────────────────

  @override
  Future<UserProfileDto?> getUserProfile(String uid) async {
    final doc = await _usersCol.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfileDto.fromFirestore(doc.id, doc.data()!);
  }

  @override
  Future<List<UserProfileDto>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();

    // Firestore range trick for "starts with" on displayNameLower.
    final end = lowerQuery.substring(0, lowerQuery.length - 1) +
        String.fromCharCode(lowerQuery.codeUnitAt(lowerQuery.length - 1) + 1);

    final snapshot = await _usersCol
        .where('displayNameLower', isGreaterThanOrEqualTo: lowerQuery)
        .where('displayNameLower', isLessThan: end)
        .limit(20)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => UserProfileDto.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> upsertUserProfile(UserProfileDto dto) async {
    await _usersCol
        .doc(dto.uid)
        .set(dto.toFirestore(), SetOptions(merge: true));
  }

  // ── Friend Requests ─────────────────────────────────────────────────────

  @override
  Future<String> createFriendRequest({
    required String requesterId,
    required String receiverId,
  }) async {
    final now = Timestamp.now();
    final docRef = await _friendshipsCol.add({
      'requesterId': requesterId,
      'receiverId': receiverId,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
    });
    return docRef.id;
  }

  @override
  Future<void> updateFriendshipStatus(
    String friendshipId,
    String newStatus,
  ) async {
    await _friendshipsCol.doc(friendshipId).update({
      'status': newStatus,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<FriendshipDto?> findExistingFriendship(
    String userA,
    String userB,
  ) async {
    // Check A -> B
    var snapshot = await _friendshipsCol
        .where('requesterId', isEqualTo: userA)
        .where('receiverId', isEqualTo: userB)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final dto = FriendshipDto.fromFirestore(doc.id, doc.data());
      if (dto.status != 'declined') return dto;
    }

    // Check B -> A
    snapshot = await _friendshipsCol
        .where('requesterId', isEqualTo: userB)
        .where('receiverId', isEqualTo: userA)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final dto = FriendshipDto.fromFirestore(doc.id, doc.data());
      if (dto.status != 'declined') return dto;
    }

    return null;
  }

  @override
  Future<FriendshipDto?> getFriendship(String friendshipId) async {
    final doc = await _friendshipsCol.doc(friendshipId).get();
    if (!doc.exists || doc.data() == null) return null;
    return FriendshipDto.fromFirestore(doc.id, doc.data()!);
  }

  // ── Friends List ────────────────────────────────────────────────────────

  @override
  Future<List<FriendshipDto>> getAcceptedFriendships(String uid) async {
    final asRequester = await _friendshipsCol
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();

    final asReceiver = await _friendshipsCol
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();

    final all = [
      ...asRequester.docs
          .map((d) => FriendshipDto.fromFirestore(d.id, d.data())),
      ...asReceiver.docs
          .map((d) => FriendshipDto.fromFirestore(d.id, d.data())),
    ];

    final seen = <String>{};
    return all.where((f) => seen.add(f.id)).toList();
  }

  @override
  Stream<List<FriendshipDto>> watchAcceptedFriendships(String uid) {
    final asRequester = _friendshipsCol
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FriendshipDto.fromFirestore(d.id, d.data()))
            .toList());

    final asReceiver = _friendshipsCol
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FriendshipDto.fromFirestore(d.id, d.data()))
            .toList());

    return _combineListStreams(asRequester, asReceiver);
  }

  @override
  Stream<List<FriendshipDto>> watchIncomingRequests(String uid) {
    return _friendshipsCol
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FriendshipDto.fromFirestore(d.id, d.data()))
            .toList());
  }

  @override
  Stream<List<FriendshipDto>> watchOutgoingRequests(String uid) {
    return _friendshipsCol
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FriendshipDto.fromFirestore(d.id, d.data()))
            .toList());
  }

  // ── Friend Tasks ─────────────────────────────────────────────────────────

  @override
  Future<List<TaskDTO>> getTasksForUser(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('archived', isEqualTo: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TaskDTO.fromFirestore(data);
    }).toList();
  }

  // ── Meeting Proposals ──────────────────────────────────────────────────

  @override
  Future<String> saveMeetingProposal(MeetingProposalDto dto) async {
    final docRef = await _meetingProposalsCol.add(dto.toFirestore());
    return docRef.id;
  }

  @override
  Stream<List<MeetingProposalDto>> watchMeetingProposals(String uid) {
    return _meetingProposalsCol
        .where('groupMemberUids', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MeetingProposalDto.fromFirestore(d.id, d.data()))
            .toList());
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Combines two friendship-list streams by merging latest emissions.
  Stream<List<FriendshipDto>> _combineListStreams(
    Stream<List<FriendshipDto>> streamA,
    Stream<List<FriendshipDto>> streamB,
  ) {
    var latestA = <FriendshipDto>[];
    var latestB = <FriendshipDto>[];

    final controller = StreamController<List<FriendshipDto>>.broadcast();

    void emit() {
      final combined = [...latestA, ...latestB];
      final seen = <String>{};
      controller.add(combined.where((f) => seen.add(f.id)).toList());
    }

    final subA = streamA.listen(
      (data) {
        latestA = data;
        emit();
      },
      onError: controller.addError,
    );

    final subB = streamB.listen(
      (data) {
        latestB = data;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };

    return controller.stream;
  }
}
