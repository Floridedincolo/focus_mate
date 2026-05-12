import 'dart:convert';

class BlockTemplateDTO {
  final String id;
  final String name;
  final bool isWhitelist;
  final String mode;
  final List<String> packages;
  final List<String> blockedWebsites;
  final List<String> blockedKeywords;
  final Map<String, List<String>> inAppBlocks;

  const BlockTemplateDTO({
    required this.id,
    required this.name,
    this.isWhitelist = false,
    this.mode = 'hard',
    this.packages = const [],
    this.blockedWebsites = const [],
    this.blockedKeywords = const [],
    this.inAppBlocks = const {},
  });

  factory BlockTemplateDTO.fromMap(Map<String, dynamic> map) {
    final rawInApp = map['inAppBlocks'];
    Map<String, List<String>> parsedInApp = {};
    if (rawInApp is Map) {
      rawInApp.forEach((k, v) {
        if (v is List) {
          parsedInApp[k.toString()] =
              v.map((e) => e.toString()).toList(growable: false);
        }
      });
    }
    return BlockTemplateDTO(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isWhitelist: map['isWhitelist'] as bool? ?? false,
      mode: map['mode'] as String? ?? 'hard',
      packages: (map['packages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      blockedWebsites: (map['blockedWebsites'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      blockedKeywords: (map['blockedKeywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      inAppBlocks: parsedInApp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isWhitelist': isWhitelist,
      'mode': mode,
      'packages': packages,
      'blockedWebsites': blockedWebsites,
      'blockedKeywords': blockedKeywords,
      'inAppBlocks': inAppBlocks,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory BlockTemplateDTO.fromJson(String json) {
    return BlockTemplateDTO.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}
