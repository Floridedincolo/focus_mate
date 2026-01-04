import 'package:flutter/services.dart';

/// 📱 Serviciu pentru verificarea și gestionarea Accessibility Service-ului
class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('focus_mate/accessibility');

  /// ✅ Verifică dacă Accessibility Service este activ
  static Future<bool> isEnabled() async {
    try {
      final bool enabled = await _channel.invokeMethod('checkAccessibility');
      return enabled;
    } catch (e) {
      print('❌ Error checking accessibility: $e');
      return false;
    }
  }

  /// 🔓 Deschide setările de Accessibility pentru activare
  static Future<void> promptEnable() async {
    try {
      await _channel.invokeMethod('promptAccessibility');
    } catch (e) {
      print('❌ Error prompting accessibility: $e');
    }
  }

  /// 🔍 Verifică și deschide setările dacă nu e activ
  static Future<bool> checkAndPrompt() async {
    bool enabled = await isEnabled();
    if (!enabled) {
      await promptEnable();
      return false;
    }
    return true;
  }
}

