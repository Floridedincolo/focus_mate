import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_classification.dart';

class LocalAppClassificationDataSource {
  static const _prefsKey = 'app_classifications_v1';

  Future<Map<String, AppClassification>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
            k,
            AppClassification.fromJson(Map<String, dynamic>.from(v as Map)),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAll(Map<String, AppClassification> map) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      map.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_prefsKey, encoded);
  }
}
