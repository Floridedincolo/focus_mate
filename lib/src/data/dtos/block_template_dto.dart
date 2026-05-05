import 'dart:convert';

class BlockTemplateDTO {
  final String id;
  final String name;
  final bool isWhitelist;
  final List<String> packages;
  final List<String> blockedWebsites;
  final List<String> blockedKeywords;

  const BlockTemplateDTO({
    required this.id,
    required this.name,
    this.isWhitelist = false,
    this.packages = const [],
    this.blockedWebsites = const [],
    this.blockedKeywords = const [],
  });

  factory BlockTemplateDTO.fromMap(Map<String, dynamic> map) {
    return BlockTemplateDTO(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isWhitelist: map['isWhitelist'] as bool? ?? false,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isWhitelist': isWhitelist,
      'packages': packages,
      'blockedWebsites': blockedWebsites,
      'blockedKeywords': blockedKeywords,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory BlockTemplateDTO.fromJson(String json) {
    return BlockTemplateDTO.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}
