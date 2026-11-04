import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';
import 'hours_screen.dart';
import 'queue_screen.dart';

class VolunteerShell extends StatefulWidget {
  const VolunteerShell({super.key});

  @override
  State<VolunteerShell> createState() => _VolunteerShellState();
}

class _VolunteerShellState extends State<VolunteerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [QueueScreen(), HoursScreen(), ProfileScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: 'الحالات'),
          NavigationDestination(
              icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: 'ساعاتي'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}
