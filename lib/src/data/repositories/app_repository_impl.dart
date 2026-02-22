import '../../domain/repositories/app_manager_repository.dart';
import '../../domain/repositories/block_manager_repository.dart';
import '../../domain/entities/blocked_app.dart';
import '../../domain/entities/installed_application.dart';
import '../datasources/app_data_source.dart';
import '../mappers/app_mapper.dart';

/// Concrete implementation of AppManagerRepository
class AppManagerRepositoryImpl implements AppManagerRepository {
  final RemoteAppDataSource remoteDataSource;

  AppManagerRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<InstalledApplication>> getAllInstalledApps() async {
    final dtos = await remoteDataSource.getAllInstalledApps();
    return InstalledApplicationMapper.toDomainList(dtos);
  }

  @override
  Future<List<InstalledApplication>> getUserApps() async {
    final dtos = await remoteDataSource.getUserApps();
    return InstalledApplicationMapper.toDomainList(dtos);
  }

  @override
  Future<String?> getAppName(String packageName) {
    return remoteDataSource.getAppName(packageName);
  }

  @override
  Future<List<int>?> getAppIcon(String packageName) async {
    final dto = await remoteDataSource.getAppIcon(packageName);
    return dto?.iconBytes;
  }
}

/// Concrete implementation of BlockManagerRepository
class BlockManagerRepositoryImpl implements BlockManagerRepository {
  final LocalBlockedAppsDataSource localDataSource;

  BlockManagerRepositoryImpl({required this.localDataSource});

  @override
  Future<List<BlockedApp>> getBlockedApps() async {
    final dtos = await localDataSource.getBlockedApps();
    return BlockedAppMapper.toDomainList(dtos);
  }

  @override
  Stream<List<BlockedApp>> watchBlockedApps() {
    return localDataSource.watchBlockedApps().map(BlockedAppMapper.toDomainList);
  }

  @override
  Future<void> addBlockedApp(BlockedApp app) {
    final dto = BlockedAppMapper.toDTO(app);
    return localDataSource.saveBlockedApp(dto);
  }

  @override
  Future<void> removeBlockedApp(String packageName) {
    return localDataSource.removeBlockedApp(packageName);
  }

  @override
  Future<void> setBlockedApps(List<BlockedApp> apps) {
    final dtos = BlockedAppMapper.toDTOList(apps);
    return localDataSource.setBlockedApps(dtos);
  }

  @override
  Future<void> clearBlockedApps() {
    return localDataSource.clearBlockedApps();
  }

  @override
  Future<bool> isAppBlocked(String packageName) {
    return localDataSource.isAppBlocked(packageName);
  }
}

