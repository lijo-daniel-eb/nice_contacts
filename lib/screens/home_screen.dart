import 'package:flutter/material.dart';
import 'package:my_contacts/screens/contacts_screen.dart';
import 'package:my_contacts/screens/favourites_screen.dart';
import 'package:my_contacts/screens/recents_screen.dart';
import 'package:my_contacts/screens/settings_screen.dart';
import 'package:my_contacts/screens/smart_insights_screen.dart';
import 'package:my_contacts/services/preferences_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  final _prefsService = PreferencesService();
  final _favouritesKey = GlobalKey<FavouritesScreenState>();
  final _contactsKey = GlobalKey<ContactsScreenState>();

  late final List<Widget> _screens = [
    ContactsScreen(key: _contactsKey),
    FavouritesScreen(key: _favouritesKey),
    const RecentsScreen(),
    const SmartInsightsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = _prefsService.getDefaultTab();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            _contactsKey.currentState?.refresh();
          } else if (index == 1) {
            _favouritesKey.currentState?.refresh();
          }
        },
        indicatorColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
        animationDuration: const Duration(milliseconds: 400),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts_rounded),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Favourites',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Recents',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology_rounded),
            label: 'Smart',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
