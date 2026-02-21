import 'package:flutter/material.dart';
import 'package:focus_mate/pages/home.dart';
import 'package:focus_mate/pages/focus_page.dart';
import 'package:focus_mate/pages/stats_page.dart';
import 'package:focus_mate/pages/profile.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const Home(),
    const FocusPage(),
    const StatsPage(),
    const Profile(),
  ];

  final bottomBarColor = const Color(0xFF1A1A1A);
  final accentColor = Colors.blueAccent;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        shape: const CircleBorder(),
        elevation: 2,
        onPressed: () => Navigator.pushNamed(context, '/add_task'),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: bottomBarColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomNavItem(0, Icons.home_outlined, Icons.home, "Home"),
              _buildBottomNavItem(
                1,
                Icons.shield_outlined,
                Icons.shield,
                "Focus",
              ),
              const SizedBox(width: 48), // Spațiu pentru FAB
              _buildBottomNavItem(
                2,
                Icons.bar_chart_outlined,
                Icons.bar_chart,
                "Stats",
              ),
              _buildBottomNavItem(
                3,
                Icons.person_outline,
                Icons.person,
                "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.blueAccent : Colors.grey,
              size: 22,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
