import '../../presentation/pages/stats/models/app_category.dart';

class AppClassification {
  final String packageName;
  final AppCategory? userCategory;
  final bool excluded;

  const AppClassification({
    required this.packageName,
    this.userCategory,
    this.excluded = false,
  });

  AppClassification copyWith({
    AppCategory? userCategory,
    bool? clearUserCategory,
    bool? excluded,
  }) {
    return AppClassification(
      packageName: packageName,
      userCategory: (clearUserCategory ?? false) ? null : (userCategory ?? this.userCategory),
      excluded: excluded ?? this.excluded,
    );
  }

  Map<String, dynamic> toJson() => {
        'p': packageName,
        if (userCategory != null) 'c': userCategory!.name,
        'e': excluded,
      };

  static AppClassification fromJson(Map<String, dynamic> json) {
    final cat = json['c'] as String?;
    return AppClassification(
      packageName: json['p'] as String,
      userCategory: cat == null
          ? null
          : AppCategory.values.firstWhere(
              (e) => e.name == cat,
              orElse: () => AppCategory.neutral,
            ),
      excluded: (json['e'] as bool?) ?? false,
    );
  }
}
