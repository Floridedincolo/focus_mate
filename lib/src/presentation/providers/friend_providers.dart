import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/entities/meeting_proposal.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/friend_repository.dart';
import '../../domain/usecases/friend_usecases.dart';
import '../../domain/usecases/suggest_meeting_algorithmic_use_case.dart';
import '../../domain/usecases/suggest_meeting_ai_use_case.dart';

// ── Current User ─────────────────────────────────────────────────────────────

/// Reactive stream of the Firebase Auth user — re-emits whenever the user
/// signs in, signs out, or the token refreshes.
final _authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Nullable UID — `null` when the user is not signed in.
/// Backed by [_authStateProvider] so every downstream provider that watches
/// this will automatically re-evaluate when the auth state changes.
final currentUserUidProvider = Provider<String?>((ref) {
  return ref.watch(_authStateProvider).valueOrNull?.uid;
});

/// Non-null convenience — throws only when explicitly read from a context
/// where the user is guaranteed to be signed in.
String requireUid(WidgetRef ref) {
  final uid = ref.read(currentUserUidProvider);
  if (uid == null) throw StateError('User is not signed in');
  return uid;
}

// ── Use Case providers ───────────────────────────────────────────────────────

final sendFriendRequestUseCaseProvider = Provider(
  (ref) => getIt<SendFriendRequestUseCase>(),
);

final acceptFriendRequestUseCaseProvider = Provider(
  (ref) => getIt<AcceptFriendRequestUseCase>(),
);

final declineFriendRequestUseCaseProvider = Provider(
  (ref) => getIt<DeclineFriendRequestUseCase>(),
);

final getFriendsListUseCaseProvider = Provider(
  (ref) => getIt<GetFriendsListUseCase>(),
);

final watchFriendsUseCaseProvider = Provider(
  (ref) => getIt<WatchFriendsUseCase>(),
);

final watchIncomingRequestsUseCaseProvider = Provider(
  (ref) => getIt<WatchIncomingRequestsUseCase>(),
);

final suggestMeetingAlgorithmicUseCaseProvider = Provider(
  (ref) => getIt<SuggestMeetingAlgorithmicUseCase>(),
);

final suggestMeetingAiUseCaseProvider = Provider(
  (ref) => getIt<SuggestMeetingAiUseCase>(),
);

final friendRepositoryProvider = Provider(
  (ref) => getIt<FriendRepository>(),
);

// ── Stream providers ─────────────────────────────────────────────────────────

/// Real-time stream of accepted friends for the current user.
/// Returns empty list when not signed in.
final watchFriendsProvider = StreamProvider<List<UserProfile>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final useCase = ref.watch(watchFriendsUseCaseProvider);
  return useCase(uid);
});

/// Real-time stream of incoming (pending) friend requests.
/// Returns empty list when not signed in.
final watchIncomingRequestsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final useCase = ref.watch(watchIncomingRequestsUseCaseProvider);
  return useCase(uid);
});

/// Real-time stream of outgoing (pending) friend requests sent by the current user.
/// Returns empty list when not signed in.
final watchOutgoingRequestsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(friendRepositoryProvider);
  return repo.watchOutgoingRequests(uid);
});

/// Real-time stream of meeting proposals involving the current user.
/// Returns empty list when not signed in.
final watchMeetingProposalsProvider =
    StreamProvider<List<MeetingProposal>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(friendRepositoryProvider);
  return repo.watchMeetingProposals(uid);
});

// ── Action providers ─────────────────────────────────────────────────────────

/// Search users by display name.
final searchUsersProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, query) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return [];
  final repo = ref.watch(friendRepositoryProvider);
  return repo.searchUsers(query, currentUserId: uid);
});

/// Send a friend request to [receiverId].
Future<void> sendFriendRequest(WidgetRef ref, String receiverId) async {
  final uid = requireUid(ref);
  final useCase = ref.read(sendFriendRequestUseCaseProvider);
  await useCase(requesterId: uid, receiverId: receiverId);
}

/// Accept a friend request by [friendshipId].
Future<void> acceptFriendRequest(WidgetRef ref, String friendshipId) async {
  final useCase = ref.read(acceptFriendRequestUseCaseProvider);
  await useCase(friendshipId);
}

/// Decline a friend request by [friendshipId].
Future<void> declineFriendRequest(WidgetRef ref, String friendshipId) async {
  final useCase = ref.read(declineFriendRequestUseCaseProvider);
  await useCase(friendshipId);
}

