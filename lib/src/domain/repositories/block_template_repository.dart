import '../entities/app_block_template.dart';

abstract class BlockTemplateRepository {
  Future<List<AppBlockTemplate>> getTemplates();
  Future<AppBlockTemplate?> getTemplateById(String id);
  Future<void> saveTemplate(AppBlockTemplate template);
  Future<void> deleteTemplate(String id);
}
