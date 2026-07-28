import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'categories_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Root scaffold after splash — provides the bottom navigation that
/// hosts the calendar, search, categories, and settings tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Each tab keeps its own state (and nested routes) when the user
  /// switches away and back. We use IndexedStack to preserve those.
  final _pages = const [
    CalendarScreen(embedded: true),
    SearchScreen(),
    CategoriesScreen(),
    SettingsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search_rounded),
      label: 'Search',
    ),
    NavigationDestination(
      icon: Icon(Icons.category_outlined),
      selectedIcon: Icon(Icons.category_rounded),
      label: 'Categories',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
