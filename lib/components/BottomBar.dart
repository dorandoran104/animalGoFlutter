// components/bottom_nav_bar.dart
import 'package:flutter/material.dart';

class Bottombar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const Bottombar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.grey.shade50,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.black38.withOpacity(0.4),
      onTap: onTabSelected,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '메인',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on),
          label: '마을페이지',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message),
          label: '채팅',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '마이페이지',
        ),
      ],
    );
  }
}