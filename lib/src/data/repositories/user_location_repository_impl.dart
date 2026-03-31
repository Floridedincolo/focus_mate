import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/meeting_location.dart';
import '../../domain/repositories/user_location_repository.dart';
import '../dtos/user_profile_dto.dart';

/// Firestore-backed implementation of [UserLocationRepository].
///
/// Locations are stored as sub-fields (`homeLocation`, `workLocation`) inside
/// the user's Firestore document at `users/{uid}`. This ensures the data
/// persists across device reinstalls and is tied to the authenticated user.
class UserLocationRepositoryImpl implements UserLocationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserLocationRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Returns a [DocumentReference] to the current user's profile document.
  /// Returns `null` if the user is not authenticated.
  DocumentReference<Map<String, dynamic>>? get _userDocRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  @override
  Future<void> saveUserLocations({
    MeetingLocation? home,
    MeetingLocation? work,
  }) async {
    final docRef = _userDocRef;
    if (docRef == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Cannot save locations: user not authenticated');
      }
      return;
    }

    final Map<String, dynamic> updates = {};

    if (home != null) {
      updates['homeLocation'] = LocationFieldDto(
        name: home.name,
        latitude: home.latitude,
        longitude: home.longitude,
      ).toMap();
    } else {
      updates['homeLocation'] = FieldValue.delete();
    }

    if (work != null) {
      updates['workLocation'] = LocationFieldDto(
        name: work.name,
        latitude: work.latitude,
        longitude: work.longitude,
      ).toMap();
    } else {
      updates['workLocation'] = FieldValue.delete();
    }

    await docRef.set(updates, SetOptions(merge: true));
  }

  @override
  Future<(MeetingLocation?, MeetingLocation?)> getUserLocations() async {
    final docRef = _userDocRef;
    if (docRef == null) return (null, null);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return (null, null);

      final data = snapshot.data()!;

      final home = data['homeLocation'] != null
          ? _locationFromMap(data['homeLocation'] as Map<String, dynamic>)
          : null;
      final work = data['workLocation'] != null
          ? _locationFromMap(data['workLocation'] as Map<String, dynamic>)
          : null;

      return (home, work);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error reading locations from Firestore: $e');
      }
      return (null, null);
    }
  }

  @override
  Future<bool> hasCompletedSetup() async {
    final docRef = _userDocRef;
    if (docRef == null) return false;

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return false;

      final data = snapshot.data()!;
      return data['locationSetupComplete'] == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking setup status: $e');
      }
      return false;
    }
  }

  @override
  Future<void> markSetupComplete() async {
    final docRef = _userDocRef;
    if (docRef == null) return;

    await docRef.set(
      {'locationSetupComplete': true},
      SetOptions(merge: true),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  MeetingLocation _locationFromMap(Map<String, dynamic> map) {
    return MeetingLocation(
      name: map['name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
