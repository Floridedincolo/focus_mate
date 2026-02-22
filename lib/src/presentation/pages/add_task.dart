import 'package:flutter/material.dart';

class AddTaskMenu extends StatefulWidget {
  const AddTaskMenu({super.key});

  @override
  State<AddTaskMenu> createState() => _AddTaskMenuState();
}

class _AddTaskMenuState extends State<AddTaskMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Add Task'),
      ),
      body: const Center(
        child: Text('Add Task Page - Coming Soon'),
      ),
    );
  }
}

