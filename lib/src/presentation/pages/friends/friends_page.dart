import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/friend_providers.dart';
import 'user_search_tab.dart';
import 'friend_requests_tab.dart';
import 'friends_list_tab.dart';
import 'meetings_tab.dart';

/// Main Friends page with 4 tabs: Search, Requests, Friends, Meetings.
class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(watchIncomingRequestsProvider);
    final badgeCount = incomingAsync.valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D0D),
          title: const Text(
            'Friends',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white54,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              const Tab(icon: Icon(Icons.search), text: 'Search'),
              Tab(
                child: Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text('$badgeCount'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail_outline),
                        SizedBox(height: 4),
                        Text('Requests', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const Tab(icon: Icon(Icons.people), text: 'Friends'),
              const Tab(icon: Icon(Icons.event), text: 'Meetings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            UserSearchTab(),
            FriendRequestsTab(),
            FriendsListTab(),
            MeetingsTab(),
          ],
        ),
      ),
    );
  }
}
