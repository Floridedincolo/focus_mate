class AppBlockTemplate {
  final String id;
  final String name;
  final bool isWhitelist;
  // 'hard' = re-blocks aggressively (5s cooldown).
  // 'light' = warns once, then leaves the app alone for 30s.
  final String mode;
  final List<String> packages;
  final List<String> blockedWebsites;
  final List<String> blockedKeywords;

  const AppBlockTemplate({
    required this.id,
    required this.name,
    this.isWhitelist = false,
    this.mode = 'hard',
    this.packages = const [],
    this.blockedWebsites = const [],
    this.blockedKeywords = const [],
  });

  AppBlockTemplate copyWith({
    String? id,
    String? name,
    bool? isWhitelist,
    String? mode,
    List<String>? packages,
    List<String>? blockedWebsites,
    List<String>? blockedKeywords,
  }) {
    return AppBlockTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      isWhitelist: isWhitelist ?? this.isWhitelist,
      mode: mode ?? this.mode,
      packages: packages ?? this.packages,
      blockedWebsites: blockedWebsites ?? this.blockedWebsites,
      blockedKeywords: blockedKeywords ?? this.blockedKeywords,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppBlockTemplate &&
        other.id == id &&
        other.name == name &&
        other.isWhitelist == isWhitelist &&
        other.mode == mode &&
        _listEquals(other.packages, packages) &&
        _listEquals(other.blockedWebsites, blockedWebsites) &&
        _listEquals(other.blockedKeywords, blockedKeywords);
  }

  @override
  int get hashCode => Object.hash(id, name, isWhitelist, mode, Object.hashAll(packages), Object.hashAll(blockedWebsites), Object.hashAll(blockedKeywords));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
