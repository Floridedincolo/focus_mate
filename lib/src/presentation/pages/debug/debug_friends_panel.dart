import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug-only panel for testing the Friends & Meeting features with
/// a single emulator / device.
class DebugFriendsPanel extends ConsumerStatefulWidget {
  const DebugFriendsPanel({super.key});

  @override
  ConsumerState<DebugFriendsPanel> createState() => _DebugFriendsPanelState();
}

class _DebugFriendsPanelState extends ConsumerState<DebugFriendsPanel> {
  static const _testBuddyUid = 'debug_test_buddy_001';
  static const _testBuddyName = 'Test Buddy';
  static const _testBuddyEmail = 'testbuddy@debug.local';

  bool _loading = false;
  String _status = '';

  Future<void> _seedTestBuddy() async {
    setState(() {
      _loading = true;
      _status = 'Creating test buddy…';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(_testBuddyUid).set({
        'displayName': _testBuddyName,
        'displayNameLower': _testBuddyName.toLowerCase(),
        'email': _testBuddyEmail,
        'photoUrl': null,
      }, SetOptions(merge: true));

      setState(() => _status = 'Test buddy "$_testBuddyName" created in users/ collection.');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendFriendRequestFromBuddy() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _status = 'Not signed in');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Sending friend request from test buddy…';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final now = Timestamp.now();

      final existing = await firestore
          .collection('friendships')
          .where('requesterId', isEqualTo: _testBuddyUid)
          .where('receiverId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(
            () => _status = 'Friendship already exists (id: ${existing.docs.first.id})');
        setState(() => _loading = false);
        return;
      }

      await firestore.collection('friendships').add({
        'requesterId': _testBuddyUid,
        'receiverId': currentUser.uid,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      setState(() =>
          _status = 'Pending friend request created from Test Buddy to You.\n'
              'Go to Friends > Requests tab to accept it.');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createAcceptedFriendship() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _status = 'Not signed in');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Creating accepted friendship…';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final now = Timestamp.now();

      await firestore.collection('users').doc(_testBuddyUid).set({
        'displayName': _testBuddyName,
        'displayNameLower': _testBuddyName.toLowerCase(),
        'email': _testBuddyEmail,
      }, SetOptions(merge: true));

      final existing = await firestore
          .collection('friendships')
          .where('requesterId', isEqualTo: _testBuddyUid)
          .where('receiverId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'status': 'accepted',
          'updatedAt': now,
        });
        setState(() => _status = 'Existing friendship set to "accepted".');
      } else {
        await firestore.collection('friendships').add({
          'requesterId': _testBuddyUid,
          'receiverId': currentUser.uid,
          'status': 'accepted',
          'createdAt': now,
          'updatedAt': now,
        });
        setState(() => _status = 'Accepted friendship created.\n'
            'Go to Friends > My Friends tab to see Test Buddy.');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addTestBuddyTasks() async {
    setState(() {
      _loading = true;
      _status = 'Adding tasks to test buddy schedule…';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final tasksRef = firestore
          .collection('users')
          .doc(_testBuddyUid)
          .collection('tasks');

      final existing = await tasksRef.get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await tasksRef.add({
        'title': 'Morning Lecture',
        'description': 'Computer Science 101',
        'startDate': Timestamp.fromDate(today),
        'startTime': '09:00',
        'endTime': '10:30',
        'oneTime': false,
        'archived': false,
        'days': {
          'Mon': true, 'Tue': true, 'Wed': true,
          'Thu': true, 'Fri': true, 'Sat': false, 'Sun': false,
        },
      });

      await tasksRef.add({
        'title': 'Gym',
        'description': 'Workout session',
        'startDate': Timestamp.fromDate(today),
        'startTime': '14:00',
        'endTime': '15:30',
        'oneTime': false,
        'archived': false,
        'days': {
          'Mon': true, 'Tue': false, 'Wed': true,
          'Thu': false, 'Fri': true, 'Sat': false, 'Sun': false,
        },
      });

      setState(() => _status = '2 sample tasks added to Test Buddy\'s schedule.\n'
          'Now try Plan a Meeting to see how slots are computed.');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cleanupAll() async {
    setState(() {
      _loading = true;
      _status = 'Cleaning up…';
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final q1 = await firestore
          .collection('friendships')
          .where('requesterId', isEqualTo: _testBuddyUid)
          .get();
      final q2 = await firestore
          .collection('friendships')
          .where('receiverId', isEqualTo: _testBuddyUid)
          .get();
      for (final doc in [...q1.docs, ...q2.docs]) {
        await doc.reference.delete();
      }

      final tasks = await firestore
          .collection('users')
          .doc(_testBuddyUid)
          .collection('tasks')
          .get();
      for (final doc in tasks.docs) {
        await doc.reference.delete();
      }

      await firestore.collection('users').doc(_testBuddyUid).delete();

      setState(() => _status = 'All test data cleaned up.');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Debug: Friends Testing',
            style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Single-device testing tools',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'These tools create fake data directly in Firestore to simulate '
              'a second user. Use them to test the Friends & Meeting '
              'features without needing a second device or account.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),

            _buildActionButton(
              icon: Icons.person_add,
              label: 'Step 1: Create Test Buddy',
              subtitle: 'Adds a fake user profile to Firestore',
              color: Colors.blueAccent,
              onPressed: _loading ? null : _seedTestBuddy,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.mail,
              label: 'Step 2a: Send Friend Request (from buddy)',
              subtitle: 'Creates a pending request you can accept',
              color: Colors.orangeAccent,
              onPressed: _loading ? null : _sendFriendRequestFromBuddy,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.check_circle,
              label: 'Step 2b: Create Accepted Friendship',
              subtitle: 'Skip pending — directly become friends',
              color: Colors.green,
              onPressed: _loading ? null : _createAcceptedFriendship,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.event_note,
              label: 'Step 3: Add Tasks to Test Buddy',
              subtitle: 'Sample schedule for meeting suggestions',
              color: Colors.purpleAccent,
              onPressed: _loading ? null : _addTestBuddyTasks,
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              icon: Icons.delete_forever,
              label: 'Cleanup All Test Data',
              subtitle: 'Remove test buddy and all related data',
              color: Colors.redAccent,
              onPressed: _loading ? null : _cleanupAll,
            ),

            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            ],

            if (_status.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.6),
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
