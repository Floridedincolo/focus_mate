import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../domain/usecases/notification_usecases.dart';

final toggleNotificationsUseCaseProvider = Provider(
  (ref) => getIt<ToggleNotificationsUseCase>(),
);

final notificationsEnabledProvider = FutureProvider<bool>((ref) {
  return getIt<GetNotificationsEnabledUseCase>()();
});
