/// Platform data source for querying Android UsageStats.
abstract class UsageStatsDataSource {
  /// Whether the app has been granted PACKAGE_USAGE_STATS permission.
  Future<bool> hasUsagePermission();

  /// Opens the system Usage Access settings screen.
  Future<void> requestUsagePermission();

  /// Returns usage stats for the last [days] days as a raw map with keys:
  /// `totalScreenTimeMinutes`, `hourlyUsage` (24 ints), `topApps` (list of maps).
  Future<Map<String, dynamic>> getUsageStats({int days = 1});
}
