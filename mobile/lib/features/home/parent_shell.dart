import 'package:flutter/material.dart';

import '../children/children_screen.dart';
import '../library/library_screen.dart';
import '../profile/profile_screen.dart';
import 'home_tab.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _tab = 0;

  static const _pages = [HomeTab(), ChildrenScreen(), LibraryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.child_care_outlined), selectedIcon: Icon(Icons.child_care_rounded), label: 'أطفالي'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'المكتبة'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}
