import 'package:flutter/material.dart';
import '../../../domain/entities/user_profile.dart';

/// Reusable tile for displaying a [UserProfile] with a trailing action.
class UserProfileTile extends StatelessWidget {
  final UserProfile profile;
  final Widget? trailing;
  final VoidCallback? onTap;

  const UserProfileTile({
    super.key,
    required this.profile,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
        backgroundImage:
            profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
        onBackgroundImageError:
            profile.photoUrl != null ? (_, __) {} : null,
        child: profile.photoUrl == null
            ? Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(
        profile.displayName,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: profile.email != null
          ? Text(profile.email!,
              style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      trailing: trailing,
    );
  }
}

