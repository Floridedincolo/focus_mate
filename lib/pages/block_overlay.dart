import 'package:flutter/material.dart';

class BlockOverlay extends StatelessWidget {
  final String appName;

  const BlockOverlay({super.key, required this.appName});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8), // fundal semi-transparent
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, color: Colors.red, size: 80),
            SizedBox(height: 20),
            Text(
              "$appName este blocată!",
              style: TextStyle(color: Colors.white, fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
