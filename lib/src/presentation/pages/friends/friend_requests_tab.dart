import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/friendship.dart';
import '../../../domain/entities/user_profile.dart';
import '../../providers/friend_providers.dart';
import '../../widgets/friends/user_profile_tile.dart';

/// Tab showing incoming friend requests with the requester's profile info.
class FriendRequestsTab extends ConsumerWidget {
  const FriendRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(watchIncomingRequestsProvider);

    return incomingAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (incoming) {
        if (incoming.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline, color: Colors.white24, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: incoming.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Colors.white12, height: 1, indent: 16),
          itemBuilder: (context, i) {
            final f = incoming[i];
            return _IncomingRequestTile(friendship: f);
          },
        );
      },
    );
  }
}

class _IncomingRequestTile extends ConsumerStatefulWidget {
  final Friendship friendship;
  const _IncomingRequestTile({required this.friendship});

  @override
  ConsumerState<_IncomingRequestTile> createState() =>
      _IncomingRequestTileState();
}

class _IncomingRequestTileState extends ConsumerState<_IncomingRequestTile> {
  bool _loading = false;
  String? _result;
  UserProfile? _requesterProfile;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequesterProfile();
  }

  Future<void> _loadRequesterProfile() async {
    try {
      final repo = ref.read(friendRepositoryProvider);
      final profile =
          await repo.getUserProfile(widget.friendship.requesterId);
      if (mounted) {
        setState(() {
          _requesterProfile = profile;
          _profileLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      final uc = ref.read(acceptFriendRequestUseCaseProvider);
      await uc(widget.friendship.id);
      if (mounted) setState(() => _result = 'accepted');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    try {
      final uc = ref.read(declineFriendRequestUseCaseProvider);
      await uc(widget.friendship.id);
      if (mounted) setState(() => _result = 'declined');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _requesterProfile;

    if (profile != null) {
      return UserProfileTile(
        profile: profile,
        trailing: _buildTrailing(),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
        child: _profileLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.blueAccent))
            : const Icon(Icons.person, color: Colors.blueAccent, size: 20),
      ),
      title: Text(
        widget.friendship.requesterId,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(),
      trailing: _buildTrailing(),
    );
  }

  Widget? _buildSubtitle() {
    if (_result != null) {
      return Text(
        _result == 'accepted' ? 'Accepted' : 'Declined',
        style: TextStyle(
          color: _result == 'accepted' ? Colors.green : Colors.white38,
          fontSize: 12,
        ),
      );
    }
    return const Text('Pending',
        style: TextStyle(color: Colors.orangeAccent, fontSize: 12));
  }

  Widget? _buildTrailing() {
    if (_result != null) return null;
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _accept,
          icon: const Icon(Icons.check_circle,
              color: Colors.green, size: 28),
          tooltip: 'Accept',
        ),
        IconButton(
          onPressed: _decline,
          icon: const Icon(Icons.cancel,
              color: Colors.redAccent, size: 28),
          tooltip: 'Decline',
        ),
      ],
    );
  }
}
