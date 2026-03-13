import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_contacts/screens/contacts_screen.dart';
import 'package:my_contacts/screens/favourites_screen.dart';
import 'package:my_contacts/screens/recents_screen.dart';
import 'package:my_contacts/screens/settings_screen.dart';
import 'package:my_contacts/screens/smart_insights_screen.dart';
import 'package:my_contacts/services/fake_call_scheduler_service.dart';
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
    FakeCallSchedulerService().startDueScheduleWatcher();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FakeCallSchedulerService().processPendingNotificationTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.75),
              border: Border(
                top: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
                if (index == 0) {
                  _contactsKey.currentState?.refresh();
                } else if (index == 1) {
                  _favouritesKey.currentState?.refresh();
                }
              },
              indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              animationDuration: const Duration(milliseconds: 500),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                _buildNavDestination(
                  Icons.contacts_outlined,
                  Icons.contacts_rounded,
                  'Contacts',
                  const Color(0xFF1B98E0),
                  0,
                ),
                _buildNavDestination(
                  Icons.star_outline_rounded,
                  Icons.star_rounded,
                  'Favourites',
                  const Color(0xFFFFA62E),
                  1,
                ),
                _buildNavDestination(
                  Icons.history_outlined,
                  Icons.history_rounded,
                  'Recents',
                  const Color(0xFF00C9FF),
                  2,
                ),
                _buildNavDestination(
                  Icons.psychology_outlined,
                  Icons.psychology_rounded,
                  'Smart',
                  const Color(0xFF4ECDC4),
                  3,
                ),
                _buildNavDestination(
                  Icons.settings_outlined,
                  Icons.settings_rounded,
                  'Settings',
                  colorScheme.primary,
                  4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavDestination(
    IconData icon,
    IconData selectedIcon,
    String label,
    Color accentColor,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return NavigationDestination(
      icon: Icon(icon, color: isSelected ? accentColor : null),
      selectedIcon: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.7)],
        ).createShader(bounds),
        child: Icon(selectedIcon, color: Colors.white),
      ),
      label: label,
    );
  }
}
