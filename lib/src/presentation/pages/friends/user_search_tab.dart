import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/friend_providers.dart';
import '../../widgets/friends/user_profile_tile.dart';

/// Tab for searching users and sending friend requests.
class UserSearchTab extends ConsumerStatefulWidget {
  const UserSearchTab({super.key});

  @override
  ConsumerState<UserSearchTab> createState() => _UserSearchTabState();
}

class _UserSearchTabState extends ConsumerState<UserSearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      if (trimmed.length >= 2 && trimmed != _query) {
        setState(() => _query = trimmed);
      }
    });
  }

  Future<void> _sendRequest(String receiverId) async {
    try {
      final uid = requireUid(ref);
      final useCase = ref.read(sendFriendRequestUseCaseProvider);
      await useCase(requesterId: uid, receiverId: receiverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch real-time outgoing pending requests & accepted friends
    final outgoingUids = ref.watch(watchOutgoingRequestsProvider).valueOrNull
        ?.map((f) => f.receiverId)
        .toSet() ?? <String>{};
    final incomingUids = ref.watch(watchIncomingRequestsProvider).valueOrNull
        ?.map((f) => f.requesterId)
        .toSet() ?? <String>{};
    final friendUids = ref.watch(watchFriendsProvider).valueOrNull
        ?.map((p) => p.uid)
        .toSet() ?? <String>{};

    return Column(
      children: [
        // ── Search field ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by display name…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Results ──────────────────────────────────────────────────
        Expanded(
          child: _query.isEmpty
              ? const Center(
                  child: Text(
                    'Type at least 2 characters to search',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ref.watch(searchUsersProvider(_query)).when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                    data: (users) {
                      if (users.isEmpty) {
                        return const Center(
                          child: Text('No users found',
                              style: TextStyle(color: Colors.white38)),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(top: 4),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: Colors.white12,
                          height: 1,
                          indent: 72,
                        ),
                        itemBuilder: (context, i) {
                          final user = users[i];
                          final isFriend = friendUids.contains(user.uid);
                          final isPendingOut = outgoingUids.contains(user.uid);
                          final isPendingIn = incomingUids.contains(user.uid);

                          Widget trailing;
                          if (isFriend) {
                            trailing = const Chip(
                              label: Text('Friends',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          } else if (isPendingOut) {
                            trailing = const Chip(
                              label: Text('Pending',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: Colors.orangeAccent,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          } else if (isPendingIn) {
                            trailing = const Chip(
                              label: Text('Respond',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: Colors.blueAccent,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          } else {
                            trailing = IconButton(
                              onPressed: () => _sendRequest(user.uid),
                              icon: const Icon(
                                Icons.person_add,
                                color: Colors.blueAccent,
                              ),
                            );
                          }

                          return UserProfileTile(
                            profile: user,
                            trailing: trailing,
                          );
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

