import 'package:shared_preferences/shared_preferences.dart';
import '../app_data_source.dart';
import '../../dtos/app_dto.dart';

/// SharedPreferences implementation of LocalBlockedAppsDataSource
class SharedPreferencesBlockedAppsDataSource
    implements LocalBlockedAppsDataSource {
  static const _blockedAppsKey = 'focus_mate_blocked_apps';

  late SharedPreferences _prefs;

  // Listeners for stream updates
  final List<Function()> _listeners = [];

  SharedPreferencesBlockedAppsDataSource();

  /// Initialize the data source
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<List<BlockedAppDTO>> getBlockedApps() async {
    final jsonList = _prefs.getStringList(_blockedAppsKey) ?? [];
    return jsonList
        .map((json) => BlockedAppDTO.fromJson(json))
        .toList();
  }

  @override
  Stream<List<BlockedAppDTO>> watchBlockedApps() async* {
    while (true) {
      final apps = await getBlockedApps();
      yield apps;
      // Emit changes every 500ms (simple polling)
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Future<void> saveBlockedApp(BlockedAppDTO app) async {
    final apps = await getBlockedApps();
    // Remove if exists and re-add
    apps.removeWhere((a) => a.packageName == app.packageName);
    apps.add(app);
    await setBlockedApps(apps);
  }

  @override
  Future<void> removeBlockedApp(String packageName) async {
    final apps = await getBlockedApps();
    apps.removeWhere((a) => a.packageName == packageName);
    await setBlockedApps(apps);
  }

  @override
  Future<void> setBlockedApps(List<BlockedAppDTO> apps) async {
    final jsonList = apps.map((app) => app.toJson()).toList();
    await _prefs.setStringList(_blockedAppsKey, jsonList);
    // Notify listeners
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  Future<void> clearBlockedApps() async {
    await _prefs.remove(_blockedAppsKey);
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  Future<bool> isAppBlocked(String packageName) async {
    final apps = await getBlockedApps();
    return apps.any((app) => app.packageName == packageName);
  }

  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }
}

