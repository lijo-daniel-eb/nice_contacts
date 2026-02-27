import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/services/preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  final _prefsService = PreferencesService();
  int _totalContacts = 0;
  int _withPhone = 0;
  int _withEmail = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) return;
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (mounted) {
      setState(() {
        _totalContacts = contacts.length;
        _withPhone = contacts.where((c) => c.phones.isNotEmpty).length;
        _withEmail = contacts.where((c) => c.emails.isNotEmpty).length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            _buildHeader(theme, colorScheme),
            const SizedBox(height: 8),
            _buildStatsCard(theme, colorScheme),
            const SizedBox(height: 20),
            _buildSectionTitle('Appearance', theme, colorScheme),
            _buildThemeSetting(theme, colorScheme),
            _buildAccentColorSetting(theme, colorScheme),
            const SizedBox(height: 16),
            _buildSectionTitle('Display', theme, colorScheme),
            _buildShowPhoneSetting(theme, colorScheme),
            _buildSortOrderSetting(theme, colorScheme),
            _buildDefaultTabSetting(theme, colorScheme),
            const SizedBox(height: 16),
            _buildSectionTitle('Data', theme, colorScheme),
            _buildClearRecentsSetting(theme, colorScheme),
            _buildClearFavouritesSetting(theme, colorScheme),
            const SizedBox(height: 16),
            _buildSectionTitle('About', theme, colorScheme),
            _buildAboutCard(theme, colorScheme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                'Customize your experience',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primary, colorScheme.tertiary],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Statistics',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem(
                  icon: Icons.people_rounded,
                  label: 'Total',
                  value: '$_totalContacts',
                ),
                _buildStatItem(
                  icon: Icons.phone_rounded,
                  label: 'With Phone',
                  value: '$_withPhone',
                ),
                _buildStatItem(
                  icon: Icons.email_rounded,
                  label: 'With Email',
                  value: '$_withEmail',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildThemeSetting(ThemeData theme, ColorScheme colorScheme) {
    final currentTheme = _prefsService.getThemeMode();
    return _buildSettingTile(
      icon: Icons.palette_rounded,
      title: 'Theme',
      subtitle: currentTheme == 'light'
          ? 'Light'
          : currentTheme == 'dark'
          ? 'Dark'
          : 'System default',
      colorScheme: colorScheme,
      theme: theme,
      onTap: () => _showThemeDialog(colorScheme),
    );
  }

  Widget _buildAccentColorSetting(ThemeData theme, ColorScheme colorScheme) {
    final colors = [
      (0xFF6C63FF, 'Purple'),
      (0xFFFF6584, 'Pink'),
      (0xFF4CAF50, 'Green'),
      (0xFFFF9800, 'Orange'),
      (0xFF2196F3, 'Blue'),
      (0xFFE91E63, 'Rose'),
      (0xFF00BCD4, 'Teal'),
    ];
    final current = _prefsService.getAccentColor();
    final currentName = colors
        .firstWhere((c) => c.$1 == current, orElse: () => colors[0])
        .$2;

    return _buildSettingTile(
      icon: Icons.color_lens_rounded,
      title: 'Accent Color',
      subtitle: currentName,
      colorScheme: colorScheme,
      theme: theme,
      onTap: () => _showAccentColorDialog(colorScheme, colors),
    );
  }

  Widget _buildShowPhoneSetting(ThemeData theme, ColorScheme colorScheme) {
    return _buildSwitchTile(
      icon: Icons.phone_rounded,
      title: 'Show Phone in List',
      subtitle: 'Display phone number under contact name',
      value: _prefsService.getShowPhoneInList(),
      colorScheme: colorScheme,
      theme: theme,
      onChanged: (val) async {
        await _prefsService.setShowPhoneInList(val);
        setState(() {});
      },
    );
  }

  Widget _buildSortOrderSetting(ThemeData theme, ColorScheme colorScheme) {
    final order = _prefsService.getSortOrder();
    return _buildSettingTile(
      icon: Icons.sort_by_alpha_rounded,
      title: 'Sort Order',
      subtitle: order == 'firstName' ? 'First name' : 'Last name',
      colorScheme: colorScheme,
      theme: theme,
      onTap: () => _showSortDialog(colorScheme),
    );
  }

  Widget _buildDefaultTabSetting(ThemeData theme, ColorScheme colorScheme) {
    final tabs = ['Contacts', 'Favourites', 'Recents', 'Settings'];
    final current = _prefsService.getDefaultTab();
    return _buildSettingTile(
      icon: Icons.tab_rounded,
      title: 'Default Tab',
      subtitle: tabs[current],
      colorScheme: colorScheme,
      theme: theme,
      onTap: () => _showDefaultTabDialog(colorScheme, tabs),
    );
  }

  Widget _buildClearRecentsSetting(ThemeData theme, ColorScheme colorScheme) {
    return _buildSettingTile(
      icon: Icons.history_rounded,
      title: 'Clear Recent History',
      subtitle: 'Remove all recent activity data',
      colorScheme: colorScheme,
      theme: theme,
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear History'),
            content: const Text(
              'This will remove all recent activity. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await _prefsService.clearRecents();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('History cleared')),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClearFavouritesSetting(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return _buildSettingTile(
      icon: Icons.star_outline_rounded,
      title: 'Clear All Favourites',
      subtitle: 'Remove all starred contacts',
      colorScheme: colorScheme,
      theme: theme,
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear Favourites'),
            content: const Text(
              'This will unstar all favourite contacts. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final favs = _prefsService.getFavourites();
                  for (final id in favs.toList()) {
                    await _prefsService.removeFavourite(id);
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Favourites cleared')),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutCard(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.contacts_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'My Contacts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A beautiful, fast contacts app with favourites,\nrecents, smart search, and more.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Developer: Lijo Jolly',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Shared Widgets ---

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  // --- Dialogs ---

  void _showThemeDialog(ColorScheme colorScheme) {
    final current = _prefsService.getThemeMode();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption('System default', 'system', current, ctx),
            _dialogOption('Light', 'light', current, ctx),
            _dialogOption('Dark', 'dark', current, ctx),
          ],
        ),
      ),
    );
  }

  Widget _dialogOption(
    String label,
    String value,
    String current,
    BuildContext ctx,
  ) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: current,
      onChanged: (val) async {
        if (val != null) {
          await _prefsService.setThemeMode(val);
          Navigator.pop(ctx);
          setState(() {});
        }
      },
    );
  }

  void _showSortDialog(ColorScheme colorScheme) {
    final current = _prefsService.getSortOrder();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sort Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('First name'),
              value: 'firstName',
              groupValue: current,
              onChanged: (val) async {
                if (val != null) {
                  await _prefsService.setSortOrder(val);
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Last name'),
              value: 'lastName',
              groupValue: current,
              onChanged: (val) async {
                if (val != null) {
                  await _prefsService.setSortOrder(val);
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDefaultTabDialog(ColorScheme colorScheme, List<String> tabs) {
    final current = _prefsService.getDefaultTab();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default Tab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: tabs.asMap().entries.map((e) {
            return RadioListTile<int>(
              title: Text(e.value),
              value: e.key,
              groupValue: current,
              onChanged: (val) async {
                if (val != null) {
                  await _prefsService.setDefaultTab(val);
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAccentColorDialog(
    ColorScheme colorScheme,
    List<(int, String)> colors,
  ) {
    final current = _prefsService.getAccentColor();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accent Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            final isSelected = c.$1 == current;
            return GestureDetector(
              onTap: () async {
                await _prefsService.setAccentColor(c.$1);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(c.$1),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Color(c.$1).withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
