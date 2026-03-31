import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/meeting_location.dart';
import '../../domain/repositories/user_location_repository.dart';

/// SharedPreferences-backed implementation of [UserLocationRepository].
///
/// All keys are scoped by the current Firebase UID so each user has
/// their own home/work locations and onboarding state on the same device.
class UserLocationRepositoryImpl implements UserLocationRepository {
  static const _homeKeySuffix = '_home_location';
  static const _workKeySuffix = '_work_location';
  static const _setupCompleteKeySuffix = '_setup_complete';

  /// Returns the current user's UID, or `'anonymous'` as a fallback.
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  String get _homeKey => '$_uid$_homeKeySuffix';
  String get _workKey => '$_uid$_workKeySuffix';
  String get _setupCompleteKey => '$_uid$_setupCompleteKeySuffix';

  @override
  Future<void> saveUserLocations({
    MeetingLocation? home,
    MeetingLocation? work,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (home != null) {
      await prefs.setString(_homeKey, _encode(home));
    } else {
      await prefs.remove(_homeKey);
    }
    if (work != null) {
      await prefs.setString(_workKey, _encode(work));
    } else {
      await prefs.remove(_workKey);
    }

    // Sync home location to Firestore so friends can read it.
    _syncHomeToFirestore(home);
  }

  /// Writes home location to the user's Firestore document (fire-and-forget).
  void _syncHomeToFirestore(MeetingLocation? home) {
    final uid = _uid;
    if (uid == 'anonymous') return;

    final data = home != null && home.hasCoordinates
        ? {
            'homeName': home.name,
            'homeLatitude': home.latitude,
            'homeLongitude': home.longitude,
          }
        : {
            'homeName': FieldValue.delete(),
            'homeLatitude': FieldValue.delete(),
            'homeLongitude': FieldValue.delete(),
          };

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true))
        .catchError((e) {
      if (kDebugMode) debugPrint('[LOCATION] Failed to sync home to Firestore: $e');
    });
  }

  @override
  Future<(MeetingLocation?, MeetingLocation?)> getUserLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final homeJson = prefs.getString(_homeKey);
    final workJson = prefs.getString(_workKey);
    return (_decode(homeJson), _decode(workJson));
  }

  @override
  Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey) ?? false;
  }

  @override
  Future<void> markSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
  }

  // ── JSON helpers ─────────────────────────────────────────────────────

  String _encode(MeetingLocation loc) => jsonEncode({
        'name': loc.name,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
      });

  MeetingLocation? _decode(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return MeetingLocation(
        name: map['name'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

