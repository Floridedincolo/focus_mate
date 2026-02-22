import 'dart:convert' show base64;
import '../../domain/entities/blocked_app.dart';
import '../../domain/entities/installed_application.dart';
import '../dtos/app_dto.dart';

/// Mapper: InstalledApplicationDTO <-> InstalledApplication Entity
class InstalledApplicationMapper {
  static InstalledApplication toDomain(InstalledApplicationDTO dto) {
    List<int>? iconBytes;
    if (dto.iconBase64 != null && dto.iconBase64!.isNotEmpty) {
      try {
        iconBytes = base64.decode(dto.iconBase64!);
      } catch (e) {
        print('⚠️ Failed to decode icon for ${dto.appName}: $e');
      }
    }

    return InstalledApplication(
      packageName: dto.packageName,
      appName: dto.appName,
      isSystemApp: dto.isSystemApp,
      iconBytes: iconBytes,
    );
  }

  static InstalledApplicationDTO toDTO(InstalledApplication app) {
    String? iconBase64;
    if (app.iconBytes != null && app.iconBytes!.isNotEmpty) {
      iconBase64 = base64.encode(app.iconBytes!);
    }

    return InstalledApplicationDTO(
      packageName: app.packageName,
      appName: app.appName,
      isSystemApp: app.isSystemApp,
      iconBase64: iconBase64,
    );
  }

  static List<InstalledApplication> toDomainList(
    List<InstalledApplicationDTO> dtos,
  ) {
    return dtos.map(toDomain).toList();
  }
}

/// Mapper: BlockedAppDTO <-> BlockedApp Entity
class BlockedAppMapper {
  static BlockedApp toDomain(BlockedAppDTO dto) {
    return BlockedApp(
      packageName: dto.packageName,
      appName: dto.appName,
    );
  }

  static BlockedAppDTO toDTO(BlockedApp app) {
    return BlockedAppDTO(
      packageName: app.packageName,
      appName: app.appName,
    );
  }

  static List<BlockedApp> toDomainList(List<BlockedAppDTO> dtos) {
    return dtos.map(toDomain).toList();
  }

  static List<BlockedAppDTO> toDTOList(List<BlockedApp> apps) {
    return apps.map(toDTO).toList();
  }
}

