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

final _authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserUidProvider = Provider<String?>((ref) {
  return ref.watch(_authStateProvider).valueOrNull?.uid;
});

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

final watchFriendsProvider = StreamProvider<List<UserProfile>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final useCase = ref.watch(watchFriendsUseCaseProvider);
  return useCase(uid);
});

final watchIncomingRequestsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final useCase = ref.watch(watchIncomingRequestsUseCaseProvider);
  return useCase(uid);
});

final watchOutgoingRequestsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(friendRepositoryProvider);
  return repo.watchOutgoingRequests(uid);
});

final watchMeetingProposalsProvider =
    StreamProvider<List<MeetingProposal>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(friendRepositoryProvider);
  return repo.watchMeetingProposals(uid);
});

// ── Action providers ─────────────────────────────────────────────────────────

final searchUsersProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, query) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return [];
  final repo = ref.watch(friendRepositoryProvider);
  return repo.searchUsers(query, currentUserId: uid);
});

Future<void> sendFriendRequest(WidgetRef ref, String receiverId) async {
  final uid = requireUid(ref);
  final useCase = ref.read(sendFriendRequestUseCaseProvider);
  await useCase(requesterId: uid, receiverId: receiverId);
}

Future<void> acceptFriendRequest(WidgetRef ref, String friendshipId) async {
  final useCase = ref.read(acceptFriendRequestUseCaseProvider);
  await useCase(friendshipId);
}

Future<void> declineFriendRequest(WidgetRef ref, String friendshipId) async {
  final useCase = ref.read(declineFriendRequestUseCaseProvider);
  await useCase(friendshipId);
}
