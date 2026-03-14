import 'dart:ui';

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
    final navLabelStyle = MaterialStateProperty.resolveWith<TextStyle>((states) {
      final selected = states.contains(MaterialState.selected);
      return TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
      );
    });

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: colorScheme.surfaceBright.withValues(alpha: 0.55),
                  width: 1.1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surfaceBright.withValues(alpha: 0.65),
                    colorScheme.surfaceContainerLow.withValues(alpha: 0.58),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.50),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                      if (index == 0) {
                        _contactsKey.currentState?.refresh();
                      } else if (index == 1) {
                        _favouritesKey.currentState?.refresh();
                      }
                    },
                    indicatorColor: colorScheme.secondaryContainer.withValues(
                      alpha: 0.85,
                    ),
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.20),
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    animationDuration: const Duration(milliseconds: 500),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    labelTextStyle: navLabelStyle,
                    destinations: [
                      _buildNavDestination(
                        Icons.contacts_outlined,
                        Icons.contacts_rounded,
                        'Contacts',
                        const Color(0xFF1D4ED8),
                        colorScheme,
                        0,
                      ),
                      _buildNavDestination(
                        Icons.star_outline_rounded,
                        Icons.star_rounded,
                        'Favourites',
                        const Color(0xFFB45309),
                        colorScheme,
                        1,
                      ),
                      _buildNavDestination(
                        Icons.history_outlined,
                        Icons.history_rounded,
                        'Recents',
                        const Color(0xFF0F766E),
                        colorScheme,
                        2,
                      ),
                      _buildNavDestination(
                        Icons.psychology_outlined,
                        Icons.psychology_rounded,
                        'Smart',
                        const Color(0xFF7C3AED),
                        colorScheme,
                        3,
                      ),
                      _buildNavDestination(
                        Icons.settings_outlined,
                        Icons.settings_rounded,
                        'Settings',
                        const Color(0xFF334155),
                        colorScheme,
                        4,
                      ),
                    ],
                  ),
                ],
              ),
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
    ColorScheme colorScheme,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return NavigationDestination(
      icon: Icon(
        icon,
        color: isSelected
            ? accentColor
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
      ),
      selectedIcon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(selectedIcon, color: accentColor),
      ),
      label: label,
    );
  }
}
