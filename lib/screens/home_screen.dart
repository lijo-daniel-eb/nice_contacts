import 'package:flutter/material.dart';
import 'package:nice_contacts/theme/my_contacts_theme.dart';
import 'package:nice_contacts/screens/contacts_screen.dart';
import 'package:nice_contacts/screens/favourites_screen.dart';
import 'package:nice_contacts/screens/recents_screen.dart';
import 'package:nice_contacts/screens/settings_screen.dart';
import 'package:nice_contacts/screens/smart_insights_screen.dart';
import 'package:nice_contacts/services/preferences_service.dart';

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
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.onSurface.withValues(alpha: 0.09),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
              color: colorScheme.surface,
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
              indicatorColor: MyContactsColors.transparent,
              backgroundColor: MyContactsColors.transparent,
              surfaceTintColor: MyContactsColors.transparent,
              elevation: 0,
              animationDuration: const Duration(milliseconds: 350),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: [
                _buildNavDestination(
                  Icons.contacts_outlined,
                  Icons.contacts_rounded,
                  'Contacts',
                  _tabAccent(0, colorScheme),
                  colorScheme,
                  0,
                ),
                _buildNavDestination(
                  Icons.star_outline_rounded,
                  Icons.star_rounded,
                  'Favourites',
                  _tabAccent(1, colorScheme),
                  colorScheme,
                  1,
                ),
                _buildNavDestination(
                  Icons.history_outlined,
                  Icons.history_rounded,
                  'Recents',
                  _tabAccent(2, colorScheme),
                  colorScheme,
                  2,
                ),
                _buildNavDestination(
                  Icons.psychology_outlined,
                  Icons.psychology_rounded,
                  'Smart',
                  _tabAccent(3, colorScheme),
                  colorScheme,
                  3,
                ),
                _buildNavDestination(
                  Icons.settings_outlined,
                  Icons.settings_rounded,
                  'Settings',
                  _tabAccent(4, colorScheme),
                  colorScheme,
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
    ColorScheme colorScheme,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    final selectedIconColor =
        colorScheme.brightness == Brightness.dark &&
            accentColor.computeLuminance() < 0.4
        ? colorScheme.onSurface
        : accentColor;

    return NavigationDestination(
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 19,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
        ),
      ),
      selectedIcon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(
            color: selectedIconColor.withValues(alpha: 0.45),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: selectedIconColor.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(selectedIcon, color: selectedIconColor, size: 21),
      ),
      label: label,
    );
  }

  Color _tabAccent(int index, ColorScheme scheme) {
    final accents = [
      MyContactsColors.refMint,
      MyContactsColors.refYellow,
      MyContactsColors.refSky,
      MyContactsColors.refLavender,
      MyContactsColors.refCoral,
    ];
    return accents[index % accents.length];
  }
}
