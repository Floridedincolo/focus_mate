import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_block_template.dart';
import '../../domain/repositories/block_template_repository.dart';
import '../dtos/block_template_dto.dart';

class BlockTemplateRepositoryImpl implements BlockTemplateRepository {
  static const _key = 'focus_mate_block_templates';

  @override
  Future<List<AppBlockTemplate>> getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList.map((json) {
      final dto = BlockTemplateDTO.fromJson(json);
      return AppBlockTemplate(
        id: dto.id,
        name: dto.name,
        isWhitelist: dto.isWhitelist,
        packages: dto.packages,
      );
    }).toList();
  }

  @override
  Future<AppBlockTemplate?> getTemplateById(String id) async {
    final templates = await getTemplates();
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<void> saveTemplate(AppBlockTemplate template) async {
    final templates = await getTemplates();
    final index = templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      templates[index] = template;
    } else {
      templates.add(template);
    }
    await _persist(templates);
  }

  @override
  Future<void> deleteTemplate(String id) async {
    final templates = await getTemplates();
    templates.removeWhere((t) => t.id == id);
    await _persist(templates);
  }

  Future<void> _persist(List<AppBlockTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = templates.map((t) {
      return BlockTemplateDTO(
        id: t.id,
        name: t.name,
        isWhitelist: t.isWhitelist,
        packages: t.packages,
      ).toJson();
    }).toList();
    await prefs.setStringList(_key, jsonList);
  }
}
