import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:focus_mate/services/app_manager_service.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AppIcon extends StatelessWidget {
  final Uint8List? iconBytes;
  final double size;

  const AppIcon(this.iconBytes, {this.size = 40, super.key});

  @override
  Widget build(BuildContext context) {
    if (iconBytes != null) {
      return Image.memory(iconBytes!, width: size, height: size);
    } else {
      return Icon(Icons.android, size: size, color: Colors.grey);
    }
  }
}
