class AppBlockTemplate {
  final String id;
  final String name;
  final bool isWhitelist;
  final List<String> packages;

  const AppBlockTemplate({
    required this.id,
    required this.name,
    this.isWhitelist = false,
    this.packages = const [],
  });

  AppBlockTemplate copyWith({
    String? id,
    String? name,
    bool? isWhitelist,
    List<String>? packages,
  }) {
    return AppBlockTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      isWhitelist: isWhitelist ?? this.isWhitelist,
      packages: packages ?? this.packages,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppBlockTemplate &&
        other.id == id &&
        other.name == name &&
        other.isWhitelist == isWhitelist &&
        _listEquals(other.packages, packages);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, isWhitelist, Object.hashAll(packages));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
