import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:my_contacts/screens/contact_detail_screen.dart';
import 'package:my_contacts/services/call_log_service.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/direct_call_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen>
    with AutomaticKeepAliveClientMixin {
  final _repo = ContactsRepository();
  final _callLogService = CallLogService();
  List<_CallEntry> _callEntries = [];
  List<_FrequentEntry> _frequentEntries = [];
  bool _isLoading = true;
  bool _isHeaderRefreshing = false;
  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
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
    _debounce?.cancel();
    _repo.removeListener(_onRepoUpdated);
    super.dispose();
  }

  Timer? _debounce;

  void _onRepoUpdated() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    // Check call log permission first
    final status = await _callLogService.permissionStatus;
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _callEntries = [];
          _frequentEntries = [];
          _isLoading = false;
          _permissionGranted = false;
          _permissionPermanentlyDenied = status.isPermanentlyDenied;
        });
      }
      return;
    }

    await _repo.ensureLoaded();
    final allContacts = _repo.contacts;

    // Build phone-number → contact lookup (last-10-digits key for matching)
    final phoneMap = <String, Contact>{};
    for (final c in allContacts) {
      for (final phone in c.phones) {
        final raw = phone.normalizedNumber.isNotEmpty
            ? phone.normalizedNumber
            : phone.number;
        final key = CallLogService.normalizeNumber(raw);
        if (key.isNotEmpty) phoneMap[key] = c;
      }
    }

    final logEntries = await _callLogService.getEntries(limit: 200);

    // --- Recent tab: flat list of call log entries ---
    final callEntries = <_CallEntry>[];
    for (final e in logEntries.take(100)) {
      final key = CallLogService.normalizeNumber(e.number);
      final contact = key.isNotEmpty ? phoneMap[key] : null;
      callEntries.add(_CallEntry(
        contact: contact,
        number: e.number ?? '',
        displayName:
            contact?.displayName ?? e.name ?? e.number ?? 'Unknown',
        callType: e.callType ?? CallType.missed,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(e.timestamp ?? 0),
        durationSeconds: e.duration ?? 0,
      ));
    }

    // --- Frequent tab: aggregate answered calls per number ---
    final freqMap = <String, _FrequentEntry>{};
    for (final e in logEntries) {
      final type = e.callType;
      if (type != CallType.incoming && type != CallType.outgoing) continue;
      final key = CallLogService.normalizeNumber(e.number);
      final mapKey = key.isNotEmpty ? key : (e.number ?? '?');
      if (!freqMap.containsKey(mapKey)) {
        final contact = key.isNotEmpty ? phoneMap[key] : null;
        freqMap[mapKey] = _FrequentEntry(
          contact: contact,
          number: e.number ?? '',
          displayName:
              contact?.displayName ?? e.name ?? e.number ?? 'Unknown',
          count: 0,
        );
      }
      freqMap[mapKey] = freqMap[mapKey]!.copyWith(
        count: freqMap[mapKey]!.count + 1,
      );
    }
    final frequentEntries = freqMap.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    if (mounted) {
      setState(() {
        _callEntries = callEntries;
        _frequentEntries = frequentEntries.take(20).toList();
        _isLoading = false;
        _permissionGranted = true;
      });
    }
  }

  Future<void> _refreshFromHeader() async {
    if (_isHeaderRefreshing) return;
    setState(() => _isHeaderRefreshing = true);
    try {
      await _loadData();
    } finally {
      if (mounted) setState(() => _isHeaderRefreshing = false);
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
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MyContactsColors.cCC00C9FF, MyContactsColors.c991B98E0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MyContactsColors.white.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MyContactsColors.cFF00C9FF.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.history_rounded,
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
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [MyContactsColors.cFF00C9FF, MyContactsColors.cFF1B98E0],
                ).createShader(bounds),
                child: Text(
                  'Recents',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MyContactsColors.white,
                  ),
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
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              color: MyContactsColors.cFF00C9FF.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _isHeaderRefreshing ? null : _refreshFromHeader,
              icon: _isHeaderRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MyContactsColors.cFF00C9FF,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: MyContactsColors.cFF00C9FF,
                    ),
              tooltip: 'Refresh',
            ),
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
    final tabColors = index == 0
        ? [MyContactsColors.cFF00C9FF, MyContactsColors.cFF1B98E0]
        : [MyContactsColors.cFFFFA62E, MyContactsColors.cFFFF6B35];
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: tabColors) : null,
          color: isSelected ? null : MyContactsColors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tabColors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? MyContactsColors.white
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
    if (!_permissionGranted) {
      return _buildPermissionState(theme, colorScheme);
    }
    if (_callEntries.isEmpty) {
      return _buildEmptyState(
        theme,
        colorScheme,
        icon: Icons.history_rounded,
        title: 'No Recent Calls',
        subtitle: 'Your call history will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _callEntries.length,
        itemBuilder: (context, index) {
          return _buildCallTile(_callEntries[index], theme, colorScheme);
        },
      ),
    );
  }

  Widget _buildFrequentList(ThemeData theme, ColorScheme colorScheme) {
    if (!_permissionGranted) {
      return _buildPermissionState(theme, colorScheme);
    }
    if (_frequentEntries.isEmpty) {
      return _buildEmptyState(
        theme,
        colorScheme,
        icon: Icons.trending_up_rounded,
        title: 'No Frequent Contacts',
        subtitle: 'Contacts you call often\nwill appear here.',
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
          return _buildFrequentTile(
              _frequentEntries[index], index, theme, colorScheme);
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
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.15),
                    colorScheme.primaryContainer.withValues(alpha: 0.06),
                  ],
                ),
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

  /// Permission request / denied screen.
  Widget _buildPermissionState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.15),
                    colorScheme.primaryContainer.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_locked_rounded,
                size: 56,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Phone Permission Needed',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Grant access to your call history\nto load Recent and Frequently Called data.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () async {
                bool granted;
                if (_permissionPermanentlyDenied) {
                  await openAppSettings();
                  granted =
                      (await _callLogService.permissionStatus).isGranted;
                } else {
                  granted = await _callLogService.requestPermission();
                }
                if (granted && mounted) {
                  setState(() {
                    _isLoading = true;
                    _permissionGranted = true;
                  });
                  _loadData();
                }
              },
              icon: Icon(_permissionPermanentlyDenied
                  ? Icons.settings_rounded
                  : Icons.lock_open_rounded),
              label: Text(_permissionPermanentlyDenied
                  ? 'Open Settings'
                  : 'Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallTile(
    _CallEntry entry,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final number = entry.number;
    final canCall = number.isNotEmpty;

    Widget tile = _buildCallTileContent(entry, theme, colorScheme);

    if (canCall) {
      tile = Dismissible(
        key: ValueKey('call_${entry.number}_${entry.timestamp.millisecondsSinceEpoch}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _makeCall(number);
          } else {
            _sendSms(number);
          }
          return false; // keep the tile in the list
        },
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MyContactsColors.cFF43E97B, MyContactsColors.cFF38F9D7],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.call_rounded, color: MyContactsColors.white, size: 26),
              SizedBox(width: 6),
              Text(
                'Call',
                style: TextStyle(
                  color: MyContactsColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MyContactsColors.cFF2D6CDF, MyContactsColors.cFF1565C0],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Message',
                style: TextStyle(
                  color: MyContactsColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.message_rounded, color: MyContactsColors.white, size: 26),
            ],
          ),
        ),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildCallTileContent(
    _CallEntry entry,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final (icon, color) = switch (entry.callType) {
      CallType.incoming ||
      CallType.wifiIncoming =>
        (Icons.call_received_rounded, MyContactsColors.cFF4CAF50),
      CallType.outgoing ||
      CallType.wifiOutgoing =>
        (Icons.call_made_rounded, MyContactsColors.cFF2196F3),
      CallType.missed =>
        (Icons.call_missed_rounded, colorScheme.error),
      CallType.rejected ||
      CallType.blocked =>
        (Icons.call_missed_outgoing_rounded, MyContactsColors.cFFFF9800),
      _ => (Icons.phone_rounded, colorScheme.onSurface.withValues(alpha: 0.4)),
    };

    final isMissedOrRejected = entry.callType == CallType.missed ||
        entry.callType == CallType.rejected ||
        entry.callType == CallType.blocked;
    final subtitle = isMissedOrRejected
        ? _formatTimestamp(entry.timestamp)
        : '${_formatDuration(entry.durationSeconds)} · ${_formatTimestamp(entry.timestamp)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        elevation: 0.5,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: entry.contact != null
              ? () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContactDetailScreen(contact: entry.contact!),
                    ),
                  );
                  _loadData();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _buildEntryAvatar(entry.contact, entry.displayName, colorScheme),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isMissedOrRejected
                              ? color
                              : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
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
    final number = entry.number;
    final canCall = number.isNotEmpty;

    Widget tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        elevation: 0.5,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: entry.contact != null
              ? () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContactDetailScreen(contact: entry.contact!),
                    ),
                  );
                  _loadData();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: index < 3
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              MyContactsColors.cFFFFA62E,
                              MyContactsColors.cFFFF6B35,
                            ],
                          )
                        : null,
                    color: index < 3
                        ? null
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: index < 3
                            ? MyContactsColors.white
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildEntryAvatar(
                    entry.contact, entry.displayName, colorScheme),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.count} call${entry.count > 1 ? 's' : ''}',
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

    if (canCall) {
      tile = Dismissible(
        key: ValueKey('frequent_${entry.number}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _makeCall(number);
          } else {
            _sendSms(number);
          }
          return false;
        },
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MyContactsColors.cFF43E97B, MyContactsColors.cFF38F9D7],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.call_rounded, color: MyContactsColors.white, size: 26),
              SizedBox(width: 6),
              Text(
                'Call',
                style: TextStyle(
                  color: MyContactsColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MyContactsColors.cFF2D6CDF, MyContactsColors.cFF1565C0],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Message',
                style: TextStyle(
                  color: MyContactsColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.message_rounded, color: MyContactsColors.white, size: 26),
            ],
          ),
        ),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildEntryAvatar(
      Contact? contact, String displayName, ColorScheme colorScheme) {
    if (contact != null) {
      return ContactAvatar(contact: contact, radius: 24);
    }
    final color = ContactAvatar.colorFromName(displayName);
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '#';
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    await DirectCallService.call(number);
  }

  Future<void> _sendSms(String number) async {
    final uri = Uri(scheme: 'sms', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return s > 0 ? '${m}m ${s}s' : '${m}m';
    final h = m ~/ 60;
    final mm = m % 60;
    return mm > 0 ? '${h}h ${mm}m' : '${h}h';
  }
}

class _CallEntry {
  final Contact? contact;
  final String number;
  final String displayName;
  final CallType callType;
  final DateTime timestamp;
  final int durationSeconds;

  _CallEntry({
    this.contact,
    required this.number,
    required this.displayName,
    required this.callType,
    required this.timestamp,
    required this.durationSeconds,
  });
}

class _FrequentEntry {
  final Contact? contact;
  final String number;
  final String displayName;
  final int count;

  _FrequentEntry({
    this.contact,
    required this.number,
    required this.displayName,
    required this.count,
  });

  _FrequentEntry copyWith({int? count}) => _FrequentEntry(
        contact: contact,
        number: number,
        displayName: displayName,
        count: count ?? this.count,
      );
}
