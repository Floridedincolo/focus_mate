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
  // Per-app in-app feature blocks. Key = package name, value = enabled feature
  // flags (e.g. 'shorts', 'reels', 'stories', 'explore', 'comments',
  // 'video_search', 'pip'). Empty/missing = nothing extra to block for that app.
  final Map<String, List<String>> inAppBlocks;

  const AppBlockTemplate({
    required this.id,
    required this.name,
    this.isWhitelist = false,
    this.mode = 'hard',
    this.packages = const [],
    this.blockedWebsites = const [],
    this.blockedKeywords = const [],
    this.inAppBlocks = const {},
  });

  AppBlockTemplate copyWith({
    String? id,
    String? name,
    bool? isWhitelist,
    String? mode,
    List<String>? packages,
    List<String>? blockedWebsites,
    List<String>? blockedKeywords,
    Map<String, List<String>>? inAppBlocks,
  }) {
    return AppBlockTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      isWhitelist: isWhitelist ?? this.isWhitelist,
      mode: mode ?? this.mode,
      packages: packages ?? this.packages,
      blockedWebsites: blockedWebsites ?? this.blockedWebsites,
      blockedKeywords: blockedKeywords ?? this.blockedKeywords,
      inAppBlocks: inAppBlocks ?? this.inAppBlocks,
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
        _listEquals(other.blockedKeywords, blockedKeywords) &&
        _inAppBlocksEqual(other.inAppBlocks, inAppBlocks);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        isWhitelist,
        mode,
        Object.hashAll(packages),
        Object.hashAll(blockedWebsites),
        Object.hashAll(blockedKeywords),
        Object.hashAll(inAppBlocks.entries
            .map((e) => Object.hash(e.key, Object.hashAll(e.value)))),
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _inAppBlocksEqual(
      Map<String, List<String>> a, Map<String, List<String>> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_listEquals(a[key]!, b[key]!)) return false;
    }
    return true;
  }
}
