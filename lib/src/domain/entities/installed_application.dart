/// Represents a system/installed application
class InstalledApplication {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final List<int>? iconBytes;

  InstalledApplication({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.iconBytes,
  });

  InstalledApplication copyWith({
    String? packageName,
    String? appName,
    bool? isSystemApp,
    List<int>? iconBytes,
  }) {
    return InstalledApplication(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      isSystemApp: isSystemApp ?? this.isSystemApp,
      iconBytes: iconBytes ?? this.iconBytes,
    );
  }

  @override
  String toString() =>
      'InstalledApplication(packageName: $packageName, appName: $appName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InstalledApplication && other.packageName == packageName;
  }

  @override
  int get hashCode => packageName.hashCode;
}

