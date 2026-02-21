import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus_mate/extensions/task_filter.dart';

import '../models/task.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  int activeTasks = 0;
  int flawlessDays = 0;
  int totalCompletions = 0;

  bool notificationsEnabled = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
    _loadUserStats();
  }

  Future<void> _loadNotificationSetting() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? "default_user";

    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data.containsKey('notificationsEnabled')) {
        setState(() {
          notificationsEnabled = data['notificationsEnabled'];
        });
      }
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? "default_user";

    await _firestore.collection('users').doc(userId).set({
      'notificationsEnabled': value,
    }, SetOptions(merge: true));
  }

  Future<void> _loadUserStats() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? "default_user";

    try {
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .get();

      final completionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('completions')
          .get();

      final tasks = tasksSnapshot.docs
          .map((d) => Task.fromMap(d.data() as Map<String, dynamic>))
          .toList();

      final completions = completionsSnapshot.docs
          .map((d) => d.data())
          .toList();

      final Map<String, int> completionsPerDay = {};
      for (final c in completions) {
        final date = c['date'];
        final status = c['status'];
        if (status == 'completed') {
          completionsPerDay[date] = (completionsPerDay[date] ?? 0) + 1;
        }
      }

      int flawlessDays = 0;

      for (final entry in completionsPerDay.entries) {
        final date = DateTime.parse(entry.key);
        final expectedTasks = tasks
            .where((t) => t.occursOn(date) && !t.archived)
            .length;

        final completedCount = entry.value;

        if (expectedTasks > 0 && completedCount == expectedTasks) {
          flawlessDays++;
        }
      }

      setState(() {
        activeTasks = tasks.where((t) => !t.archived).length;
        totalCompletions = completions
            .where((c) => c['status'] == 'completed')
            .length;
        flawlessDays = flawlessDays;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              "Profile",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25.0,
                letterSpacing: 1.25,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: const Row(
                children: [
                  Text("English", style: TextStyle(color: Colors.white70)),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                    size: 20.0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10.0),
            IconButton(
              onPressed: _loadUserStats,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.all(10),
              ),
              icon: const Icon(Icons.refresh, size: 26.0, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20.0,
                  horizontal: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 50.0,
                      backgroundColor: Colors.white12,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Teodor Marciuc",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "teo@example.com",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const Divider(
                      color: Colors.white24,
                      thickness: 0.5,
                      height: 30.0,
                    ),

                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.fromLTRB(0, 10, 0, 15),
                      child: const Text(
                        "Quick Stats",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                        ),
                      ),
                    ),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        double cardWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildStatCard(
                              Icons.check_circle,
                              "$activeTasks",
                              "Active Tasks",
                              Colors.greenAccent,
                              cardWidth,
                            ),
                            _buildStatCard(
                              Icons.star,
                              "$flawlessDays",
                              "Flawless Days",
                              Colors.amber,
                              cardWidth,
                            ),
                            _buildStatCard(
                              Icons.local_fire_department,
                              "$totalCompletions",
                              "Completions",
                              Colors.orange,
                              cardWidth,
                            ),
                            _buildStatCard(
                              Icons.access_time,
                              "12h",
                              "Focus Hours",
                              Colors.lightBlueAccent,
                              cardWidth,
                            ),
                            _buildSimpleCard(
                              Icons.calendar_month,
                              "Full Schedule",
                              cardWidth,
                            ),
                            _buildSimpleCard(
                              Icons.pie_chart,
                              "Weekly Stats",
                              cardWidth,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 25),
                    _buildSectionTitle("Preferences"),
                    const SizedBox(height: 10),

                    _buildPreferenceRow(
                      icon: Icons.lock,
                      label: "Blocking Mode",
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            "Low",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Moderate",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "High",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPreferenceRow(
                      icon: Icons.apps,
                      label: "App Blacklist & Whitelist",
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 15,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildPreferenceRow(
                      icon: Icons.notifications,
                      label: "Notifications",
                      trailing: Switch(
                        value: notificationsEnabled,
                        activeColor: Colors.lightBlueAccent,
                        onChanged: (value) async {
                          setState(() => notificationsEnabled = value);
                          await _updateNotificationSetting(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCard(IconData icon, String label, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildPreferenceRow({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
