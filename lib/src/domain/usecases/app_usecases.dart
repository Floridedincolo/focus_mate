import '../repositories/app_manager_repository.dart';
import '../repositories/block_manager_repository.dart';
import '../entities/blocked_app.dart';
import '../entities/installed_application.dart';

/// Use case: Get all installed apps
class GetAllAppsUseCase {
  final AppManagerRepository _repository;

  GetAllAppsUseCase(this._repository);

  Future<List<InstalledApplication>> call() {
    return _repository.getAllInstalledApps();
  }
}

/// Use case: Get user apps (non-system)
class GetUserAppsUseCase {
  final AppManagerRepository _repository;

  GetUserAppsUseCase(this._repository);

  Future<List<InstalledApplication>> call() {
    return _repository.getUserApps();
  }
}

/// Use case: Get blocked apps
class GetBlockedAppsUseCase {
  final BlockManagerRepository _repository;

  GetBlockedAppsUseCase(this._repository);

  Future<List<BlockedApp>> call() {
    return _repository.getBlockedApps();
  }
}

/// Use case: Watch blocked apps changes
class WatchBlockedAppsUseCase {
  final BlockManagerRepository _repository;

  WatchBlockedAppsUseCase(this._repository);

  Stream<List<BlockedApp>> call() {
    return _repository.watchBlockedApps();
  }
}

/// Use case: Block an app
class BlockAppUseCase {
  final BlockManagerRepository _repository;

  BlockAppUseCase(this._repository);

  Future<void> call(BlockedApp app) {
    return _repository.addBlockedApp(app);
  }
}

/// Use case: Unblock an app
class UnblockAppUseCase {
  final BlockManagerRepository _repository;

  UnblockAppUseCase(this._repository);

  Future<void> call(String packageName) {
    return _repository.removeBlockedApp(packageName);
  }
}

/// Use case: Set multiple blocked apps
class SetBlockedAppsUseCase {
  final BlockManagerRepository _repository;

  SetBlockedAppsUseCase(this._repository);

  Future<void> call(List<BlockedApp> apps) {
    return _repository.setBlockedApps(apps);
  }
}

