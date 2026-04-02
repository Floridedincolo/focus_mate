import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_block_template.dart';
import '../../domain/repositories/block_template_repository.dart';
import '../dtos/block_template_dto.dart';

/// Firestore-backed implementation of [BlockTemplateRepository].
///
/// Templates are stored as documents in `users/{uid}/blockTemplates/{id}`.
/// On first run, any templates previously stored in SharedPreferences
/// are migrated to Firestore automatically.
class BlockTemplateRepositoryImpl implements BlockTemplateRepository {
  static const _localKey = 'focus_mate_block_templates';
  static const _migratedKey = 'focus_mate_block_templates_migrated';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  BlockTemplateRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get _collectionRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('blockTemplates');
  }

  /// Ensures any locally-stored templates are pushed to Firestore once.
  Future<void> _migrateLocalIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    final jsonList = prefs.getStringList(_localKey) ?? [];
    if (jsonList.isEmpty) {
      await prefs.setBool(_migratedKey, true);
      return;
    }

    final col = _collectionRef;
    if (col == null) return; // not logged in yet

    for (final json in jsonList) {
      try {
        final dto = BlockTemplateDTO.fromJson(json);
        await col.doc(dto.id).set(dto.toMap());
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Migration error for template: $e');
      }
    }

    await prefs.setBool(_migratedKey, true);
    if (kDebugMode) {
      debugPrint('✅ Migrated ${jsonList.length} block templates to Firestore');
    }
  }

  @override
  Future<List<AppBlockTemplate>> getTemplates() async {
    await _migrateLocalIfNeeded();

    final col = _collectionRef;
    if (col == null) return [];

    try {
      final snapshot = await col.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        final dto = BlockTemplateDTO.fromMap(data);
        return AppBlockTemplate(
          id: dto.id,
          name: dto.name,
          isWhitelist: dto.isWhitelist,
          packages: dto.packages,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading templates: $e');
      return [];
    }
  }

  @override
  Future<AppBlockTemplate?> getTemplateById(String id) async {
    final col = _collectionRef;
    if (col == null) return null;

    try {
      final doc = await col.doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      final dto = BlockTemplateDTO.fromMap(data);
      return AppBlockTemplate(
        id: dto.id,
        name: dto.name,
        isWhitelist: dto.isWhitelist,
        packages: dto.packages,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading template $id: $e');
      return null;
    }
  }

  @override
  Future<void> saveTemplate(AppBlockTemplate template) async {
    final col = _collectionRef;
    if (col == null) return;

    final dto = BlockTemplateDTO(
      id: template.id,
      name: template.name,
      isWhitelist: template.isWhitelist,
      packages: template.packages,
    );

    await col.doc(template.id).set(dto.toMap());
  }

  @override
  Future<void> deleteTemplate(String id) async {
    final col = _collectionRef;
    if (col == null) return;

    await col.doc(id).delete();
  }
}
