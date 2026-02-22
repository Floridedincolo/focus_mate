/// Represents a blocked app for focus mode
class BlockedApp {
  final String packageName;
  final String appName;

  BlockedApp({
    required this.packageName,
    required this.appName,
  });

  BlockedApp copyWith({
    String? packageName,
    String? appName,
  }) {
    return BlockedApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
    );
  }

  @override
  String toString() => 'BlockedApp(packageName: $packageName, appName: $appName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BlockedApp &&
        other.packageName == packageName &&
        other.appName == appName;
  }

  @override
  int get hashCode => packageName.hashCode ^ appName.hashCode;
}

