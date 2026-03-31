import 'dart:convert';

class BlockTemplateDTO {
  final String id;
  final String name;
  final bool isWhitelist;
  final List<String> packages;

  const BlockTemplateDTO({
    required this.id,
    required this.name,
    this.isWhitelist = false,
    this.packages = const [],
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isWhitelist': isWhitelist,
      'packages': packages,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory BlockTemplateDTO.fromJson(String json) {
    return BlockTemplateDTO.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}
