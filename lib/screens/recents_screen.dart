import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:my_contacts/screens/contact_detail_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen>
    with AutomaticKeepAliveClientMixin {
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();
  List<_RecentEntry> _recentEntries = [];
  List<_FrequentEntry> _frequentEntries = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Recent, 1 = Frequent

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoUpdated);
    _loadData();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdated);
    super.dispose();
  }

  void _onRepoUpdated() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    await _repo.ensureLoaded();
    final allContacts = _repo.contacts;
    final contactMap = {for (final c in allContacts) c.id: c};

    // Load recents
    final recents = _prefsService.getRecents();
    final recentEntries = <_RecentEntry>[];
    for (final r in recents) {
      final contact = contactMap[r.contactId];
      if (contact != null) {
        recentEntries.add(_RecentEntry(contact: contact, recent: r));
      }
    }

    // Load frequent
    final frequencyMap = _prefsService.getFrequentlyContacted();
    final frequentEntries = <_FrequentEntry>[];
    for (final entry in frequencyMap.entries.take(20)) {
      final contact = contactMap[entry.key];
      if (contact != null) {
        frequentEntries.add(
          _FrequentEntry(contact: contact, count: entry.value),
        );
      }
    }

    if (mounted) {
      setState(() {
        _recentEntries = recentEntries;
        _frequentEntries = frequentEntries;
        _isLoading = false;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, colorScheme),
            _buildTabSelector(colorScheme),
            Expanded(child: _buildBody(theme, colorScheme)),
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
              gradient: const LinearGradient(
                colors: [Color(0xFF00C9FF), Color(0xFF6C63FF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recents',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                'Your activity history',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_recentEntries.isNotEmpty)
            IconButton(
              onPressed: () => _showClearDialog(colorScheme),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
              tooltip: 'Clear history',
            ),
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: _tabButton('Recent', 0, colorScheme)),
            Expanded(child: _tabButton('Frequently Called', 1, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index, ColorScheme colorScheme) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_selectedTab == 0) {
      return _buildRecentList(theme, colorScheme);
    } else {
      return _buildFrequentList(theme, colorScheme);
    }
  }

  Widget _buildRecentList(ThemeData theme, ColorScheme colorScheme) {
    if (_recentEntries.isEmpty) {
      return _buildEmptyState(
        theme,
        colorScheme,
        icon: Icons.history_rounded,
        title: 'No Recent Activity',
        subtitle: 'Call or message contacts to see\nyour history here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _recentEntries.length,
        itemBuilder: (context, index) {
          final entry = _recentEntries[index];
          return _buildRecentTile(entry, theme, colorScheme);
        },
      ),
    );
  }

  Widget _buildFrequentList(ThemeData theme, ColorScheme colorScheme) {
    if (_frequentEntries.isEmpty) {
      return _buildEmptyState(
        theme,
        colorScheme,
        icon: Icons.trending_up_rounded,
        title: 'No Frequent Contacts',
        subtitle: 'Contacts you reach out to often\nwill appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 20, top: 4),
        itemCount: _frequentEntries.length,
        itemBuilder: (context, index) {
          final entry = _frequentEntries[index];
          return _buildFrequentTile(entry, index, theme, colorScheme);
        },
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTile(
    _RecentEntry entry,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final actionIcon = switch (entry.recent.action) {
      'call' => Icons.call_rounded,
      'message' => Icons.message_rounded,
      'email' => Icons.email_rounded,
      'whatsapp' => FontAwesomeIcons.whatsapp,
      _ => Icons.touch_app_rounded,
    };
    final actionColor = switch (entry.recent.action) {
      'call' => const Color(0xFF4CAF50),
      'message' => const Color(0xFF2196F3),
      'email' => const Color(0xFFFF9800),
      'whatsapp' => const Color(0xFF25D366),
      _ => colorScheme.primary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContactDetailScreen(contact: entry.contact),
              ),
            );
            _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                ContactAvatar(contact: entry.contact, radius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.contact.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(entry.recent.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(actionIcon, color: actionColor, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequentTile(
    _FrequentEntry entry,
    int index,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContactDetailScreen(contact: entry.contact),
              ),
            );
            _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // Rank badge
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: index < 3
                            ? const Color(0xFFFFA62E)
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ContactAvatar(contact: entry.contact, radius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.contact.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.count} interaction${entry.count > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Frequency bar
                Container(
                  width: 40,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _frequentEntries.isNotEmpty
                        ? entry.count / _frequentEntries.first.count
                        : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(timestamp);
  }

  void _showClearDialog(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear all recent activity?',
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
              _loadData();
            },
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _RecentEntry {
  final Contact contact;
  final RecentContact recent;
  _RecentEntry({required this.contact, required this.recent});
}

class _FrequentEntry {
  final Contact contact;
  final int count;
  _FrequentEntry({required this.contact, required this.count});
}
