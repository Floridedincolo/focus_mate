import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/friend_providers.dart';
import '../../widgets/friends/user_profile_tile.dart';
import 'plan_meeting_page.dart';

/// Tab showing the user's accepted friends with "Plan Meeting" action.
class FriendsListTab extends ConsumerWidget {
  const FriendsListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(watchFriendsProvider);

    return friendsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, color: Colors.white24, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Search for people in the Search tab',
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: friends.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Colors.white12, height: 1, indent: 72),
          itemBuilder: (context, i) {
            final friend = friends[i];
            return UserProfileTile(
              profile: friend,
              trailing: IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlanMeetingPage(
                        preselectedFriendUids: [friend.uid],
                        preselectedFriendNames: [friend.displayName],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_today,
                    color: Colors.blueAccent, size: 20),
                tooltip: 'Plan meeting',
              ),
            );
          },
        );
      },
    );
  }
}
