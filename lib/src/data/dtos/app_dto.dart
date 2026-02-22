import 'dart:convert' show json;

/// Data Transfer Object for InstalledApplication
class InstalledApplicationDTO {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final String? iconBase64;

  InstalledApplicationDTO({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.iconBase64,
  });

  factory InstalledApplicationDTO.fromMap(Map<dynamic, dynamic> data) {
    return InstalledApplicationDTO(
      packageName: data['packageName'] as String? ?? '',
      appName: data['appName'] as String? ?? '',
      isSystemApp: data['isSystemApp'] as bool? ?? false,
      iconBase64: data['iconBase64'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'isSystemApp': isSystemApp,
      'iconBase64': iconBase64,
    };
  }
}

/// Data Transfer Object for BlockedApp
class BlockedAppDTO {
  final String packageName;
  final String appName;

  BlockedAppDTO({
    required this.packageName,
    required this.appName,
  });

  factory BlockedAppDTO.fromMap(Map<String, dynamic> data) {
    return BlockedAppDTO(
      packageName: data['packageName'] as String? ?? '',
      appName: data['appName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
    };
  }

  factory BlockedAppDTO.fromJson(String jsonString) {
    final data = Map<String, dynamic>.from(
      json.decode(jsonString) as Map<dynamic, dynamic>,
    );
    return BlockedAppDTO.fromMap(data);
  }

  String toJson() {
    return json.encode(toMap());
  }
}

