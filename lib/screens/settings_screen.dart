import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:my_contacts/screens/help_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();
  int _totalContacts = 0;
  int _withPhone = 0;
  int _withEmail = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoUpdated);
    _loadStats();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _repo.removeListener(_onRepoUpdated);
    super.dispose();
  }

  Timer? _debounce;

  void _onRepoUpdated() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _loadStats();
    });
  }

  Future<void> _loadStats() async {
    await _repo.ensureLoaded();
    final contacts = _repo.contacts;
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
            const SizedBox(height: 16),
            _buildSectionTitle('Display', theme, colorScheme),
            _buildShowPhoneSetting(theme, colorScheme),
            _buildAutoAttendFakeCallsSetting(theme, colorScheme),
            _buildSortOrderSetting(theme, colorScheme),
            _buildDefaultTabSetting(theme, colorScheme),
            const SizedBox(height: 16),
            _buildSectionTitle('Data', theme, colorScheme),
            _buildCallRecordingsPathSetting(theme, colorScheme),
            _buildClearRecentsSetting(theme, colorScheme),
            _buildClearFavouritesSetting(theme, colorScheme),
            const SizedBox(height: 16),
            _buildSectionTitle('Support', theme, colorScheme),
            _buildHelpSetting(theme, colorScheme),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.7),
                      colorScheme.tertiary.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MyContactsColors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  color: MyContactsColors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ).createShader(bounds),
                child: Text(
                  'Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MyContactsColors.white,
                  ),
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
                color: MyContactsColors.white,
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
              color: MyContactsColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: MyContactsColors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: MyContactsColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: MyContactsColors.white.withValues(alpha: 0.8),
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

  Widget _buildAutoAttendFakeCallsSetting(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return _buildSwitchTile(
      icon: Icons.phone_callback_rounded,
      title: 'Auto Attend Fake Calls',
      subtitle: 'Automatically answer fake calls after a short delay',
      value: _prefsService.getAutoAttendFakeCalls(),
      colorScheme: colorScheme,
      theme: theme,
      onChanged: (val) async {
        await _prefsService.setAutoAttendFakeCalls(val);
        setState(() {});
      },
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

  Widget _buildCallRecordingsPathSetting(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final customPath = _prefsService.getCallRecordingsPath();
    final subtitle = customPath.isEmpty
        ? 'Use automatic default locations'
        : customPath;

    return _buildSettingTile(
      icon: Icons.folder_open_rounded,
      title: 'Call Recordings Folder',
      subtitle: subtitle,
      colorScheme: colorScheme,
      theme: theme,
      onTap: () => _showCallRecordingsPathDialog(colorScheme),
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

  Widget _buildHelpSetting(ThemeData theme, ColorScheme colorScheme) {
    return _buildSettingTile(
      icon: Icons.help_center_rounded,
      title: 'Help and Guide',
      subtitle: 'Learn every option and feature in this app',
      colorScheme: colorScheme,
      theme: theme,
      onTap: _openHelpPage,
    );
  }

  void _openHelpPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpScreen()),
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
                color: MyContactsColors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Contacts',
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
        color: MyContactsColors.transparent,
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

  void _showCallRecordingsPathDialog(ColorScheme colorScheme) {
    final customPath = _prefsService.getCallRecordingsPath();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded),
                  title: const Text('Choose Folder'),
                  subtitle: const Text(
                    'Pick call recordings directory using file explorer',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final selectedPath = await FilePicker.platform
                        .getDirectoryPath(dialogTitle: 'Select Call Recordings Folder');
                    if (selectedPath == null || selectedPath.trim().isEmpty) {
                      return;
                    }

                    await _prefsService.setCallRecordingsPath(selectedPath.trim());
                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Call recordings folder updated'),
                      ),
                    );
                  },
                ),
                if (customPath.isNotEmpty)
                  ListTile(
                    leading: Icon(
                      Icons.clear_rounded,
                      color: colorScheme.error,
                    ),
                    title: Text(
                      'Reset to Default Locations',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    subtitle: const Text('Remove custom folder path'),
                    onTap: () async {
                      await _prefsService.clearCallRecordingsPath();
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Using default recording locations'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
