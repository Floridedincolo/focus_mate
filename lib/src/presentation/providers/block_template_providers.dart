import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/service_locator.dart';
import '../../domain/entities/app_block_template.dart';
import '../../domain/repositories/block_template_repository.dart';

final blockTemplateRepoProvider = Provider<BlockTemplateRepository>(
  (_) => getIt<BlockTemplateRepository>(),
);

final blockTemplatesProvider = FutureProvider<List<AppBlockTemplate>>((ref) {
  return ref.watch(blockTemplateRepoProvider).getTemplates();
});

final blockTemplateByIdProvider =
    FutureProvider.family<AppBlockTemplate?, String>((ref, id) {
  return ref.watch(blockTemplateRepoProvider).getTemplateById(id);
});
