import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/service_locator.dart';
import '../../data/datasources/task_data_source.dart';
import '../../domain/entities/meeting_location.dart';
import '../providers/task_providers.dart';
import '../providers/friend_providers.dart';
import '../providers/user_location_providers.dart';
import '../providers/notification_providers.dart';
import '../widgets/location_autocomplete_field.dart';

class Profile extends ConsumerStatefulWidget {
  const Profile({super.key});

  @override
  ConsumerState<Profile> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<Profile> {
  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final locationsAsync = ref.watch(userLocationsProvider);
    final friendsAsync = ref.watch(watchFriendsProvider);
    final meetingsAsync = ref.watch(watchMeetingProposalsProvider);
    final user = FirebaseAuth.instance.currentUser;

    final displayName = user?.displayName ?? 'FocusMate User';
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;

    // ── Compute real stats from task data ──
    int activeTasks = 0;
    int archivedTasks = 0;
    int bestStreak = 0;

    tasksAsync.whenData((tasks) {
      activeTasks = tasks.where((t) => !t.archived).length;
      archivedTasks = tasks.where((t) => t.archived).length;
      for (final t in tasks) {
        if (t.streak > bestStreak) bestStreak = t.streak;
      }
    });

    final friendsCount = friendsAsync.valueOrNull?.length ?? 0;
    final meetingsCount = meetingsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            pinned: true,
            automaticallyImplyLeading: false,
            title: const Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => ref.invalidate(tasksStreamProvider),
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 4),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // ══════════════════════════════════════════
                // ── User Info Card ──
                // ══════════════════════════════════════════
                _SectionCard(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              Colors.blueAccent.withValues(alpha: 0.15),
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          onBackgroundImageError:
                              photoUrl != null ? (_, __) {} : null,
                          child: photoUrl == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // Name & email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ══════════════════════════════════════════
                // ── Focus Stats ──
                // ══════════════════════════════════════════
                _buildSectionHeader('Focus Stats'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatMiniCard(
                        icon: Icons.check_circle_outline,
                        value: '$activeTasks',
                        label: 'Active',
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatMiniCard(
                        icon: Icons.archive_outlined,
                        value: '$archivedTasks',
                        label: 'Archived',
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatMiniCard(
                        icon: Icons.local_fire_department,
                        value: '$bestStreak',
                        label: 'Best Streak',
                        color: Colors.deepOrangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ══════════════════════════════════════════
                // ── Your Locations ──
                // ══════════════════════════════════════════
                _buildSectionHeader('Your Locations'),
                const SizedBox(height: 10),
                _SectionCard(
                  children: [
                    locationsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent, strokeWidth: 2),
                        ),
                      ),
                      error: (_, __) => const Text(
                        'Failed to load locations',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      data: (locations) {
                        final (home, work) = locations;
                        return Column(
                          children: [
                            _buildLocationTile(
                              icon: Icons.home_rounded,
                              label: 'Home',
                              location: home,
                              onEdit: () => _editLocation(
                                title: 'Edit Home Location',
                                current: home,
                                onSave: (loc) async {
                                  final repo =
                                      ref.read(userLocationRepoProvider);
                                  await repo.saveUserLocations(
                                      home: loc, work: work);
                                  ref.invalidate(userLocationsProvider);
                                },
                              ),
                            ),
                            Divider(
                              color: Colors.white.withValues(alpha: 0.06),
                              height: 1,
                            ),
                            _buildLocationTile(
                              icon: Icons.school_rounded,
                              label: 'Work / University',
                              location: work,
                              onEdit: () => _editLocation(
                                title: 'Edit Work Location',
                                current: work,
                                onSave: (loc) async {
                                  final repo =
                                      ref.read(userLocationRepoProvider);
                                  await repo.saveUserLocations(
                                      home: home, work: loc);
                                  ref.invalidate(userLocationsProvider);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ══════════════════════════════════════════
                // ── Social ──
                // ══════════════════════════════════════════
                _buildSectionHeader('Social'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatMiniCard(
                        icon: Icons.people_outline,
                        value: '$friendsCount',
                        label: 'Friends',
                        color: Colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatMiniCard(
                        icon: Icons.event_outlined,
                        value: '$meetingsCount',
                        label: 'Meetings',
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  children: [
                    _buildNavRow(
                      icon: Icons.people,
                      label: 'Friends',
                      onTap: () => Navigator.pushNamed(context, '/friends'),
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    _buildNavRow(
                      icon: Icons.event,
                      label: 'Plan a Meeting',
                      onTap: () =>
                          Navigator.pushNamed(context, '/plan-meeting'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ══════════════════════════════════════════
                // ── App Settings ──
                // ══════════════════════════════════════════
                _buildSectionHeader('App Settings'),
                const SizedBox(height: 10),
                _SectionCard(
                  children: [
                    _buildNavRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'See Full Schedule',
                      onTap: () =>
                          Navigator.pushNamed(context, '/full-schedule'),
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    _buildNavRow(
                      icon: Icons.lock_outline,
                      label: 'Blocking Mode',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Moderate',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    _buildToggleRow(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      value: ref.watch(notificationsEnabledProvider).valueOrNull ?? false,
                      onChanged: (v) async {
                        await ref.read(toggleNotificationsUseCaseProvider)(v);
                        ref.invalidate(notificationsEnabledProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ══════════════════════════════════════════
                // ── Sign Out ──
                // ══════════════════════════════════════════
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await getIt<LocalTaskDataSource>().clearCache();
                      ref.invalidate(tasksStreamProvider);
                      await GoogleSignIn().signOut();
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true)
                            .pushNamedAndRemoveUntil('/', (_) => false);
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.redAccent,
                        size: 20),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: Colors.redAccent, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Helpers ──
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _buildLocationTile({
    required IconData icon,
    required String label,
    required MeetingLocation? location,
    required VoidCallback onEdit,
  }) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    location?.name ?? 'Not set',
                    style: TextStyle(
                      color: location != null ? Colors.white : Colors.white30,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            trailing ??
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            height: 28,
            child: Switch(
              value: value,
              activeColor: Colors.blueAccent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit location bottom sheet ──

  void _editLocation({
    required String title,
    required MeetingLocation? current,
    required Future<void> Function(MeetingLocation?) onSave,
  }) {
    MeetingLocation? selected = current;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  LocationAutocompleteField(
                    initialLocationName: current?.name,
                    decoration: InputDecoration(
                      hintText: 'Search for a place\u2026',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white38, size: 20),
                      suffixIcon:
                          selected != null && selected!.hasCoordinates
                              ? const Icon(Icons.check_circle,
                                  color: Colors.greenAccent, size: 20)
                              : null,
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Colors.blueAccent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onLocationSelected: (loc) {
                      setSheetState(() => selected = loc);
                    },
                  ),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        selected!.name,
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        await onSave(selected);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Reusable sub-widgets ──
// ══════════════════════════════════════════════════════════════════════════════

/// A rounded card that wraps a section's content.
class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Compact stat card used in the horizontal stats rows.
class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatMiniCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
