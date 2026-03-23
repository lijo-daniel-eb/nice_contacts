import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/screens/contact_detail_screen.dart';
import 'package:my_contacts/screens/edit_contact_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/direct_call_service.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => ContactsScreenState();
}

class ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  /// Call this from outside to trigger a UI refresh (e.g. favourites changed).
  void refresh() {
    if (mounted) setState(() {});
  }

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();
  bool _isSearching = false;
  bool _isHeaderRefreshing = false;
  late AnimationController _animController;
  Timer? _debounce;

  // Flat list items for ListView.builder
  List<_ListItem> _flatItems = [];
  // Section letter → flat-list index (for alphabet jump)
  Map<String, int> _sectionIndices = {};

  static const double _sectionHeaderHeight = 54.0;
  static const double _contactTileHeight = 72.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _repo.addListener(_onRepoUpdated);
    _fetchContacts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _repo.removeListener(_onRepoUpdated);
    _searchController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onRepoUpdated() {
    if (!mounted) return;
    final contacts = _repo.contacts;
    setState(() {
      _allContacts = contacts;
      _filteredContacts = _searchController.text.isEmpty
          ? contacts
          : _applyFilter(contacts, _searchController.text);
      _isLoading = _repo.isLoading && !_repo.hasLoaded;
      _permissionDenied = _repo.permissionDenied;
      _rebuildFlatList();
    });
    if (_repo.hasLoaded && !_animController.isCompleted) {
      _animController.forward();
    }
  }

  Future<void> _fetchContacts() async {
    await _repo.refresh();
  }

  Future<void> _refreshFromHeader() async {
    if (_isHeaderRefreshing) return;
    setState(() => _isHeaderRefreshing = true);
    try {
      await _fetchContacts();
    } finally {
      if (!mounted) return;
      setState(() => _isHeaderRefreshing = false);
    }
  }

  Future<void> _addContact() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditContactScreen()),
    );
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _applyFilter(_allContacts, query);
      _rebuildFlatList();
    });
  }

  List<Contact> _applyFilter(List<Contact> contacts, String query) {
    if (query.isEmpty) return contacts;
    final search = query.toLowerCase();
    final searchDigits = _digitsOnly(query);
    return contacts.where((contact) {
      final nameMatches = contact.displayName.toLowerCase().contains(search);
      if (nameMatches) return true;

      if (searchDigits.isEmpty) return false;
      return contact.phones.any(
        (phone) => _digitsOnly(phone.number).contains(searchDigits),
      );
    }).toList();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  // Group contacts alphabetically
  Map<String, List<Contact>> _groupContacts() {
    final Map<String, List<Contact>> grouped = {};
    for (final contact in _filteredContacts) {
      final letter = contact.displayName.isNotEmpty
          ? contact.displayName[0].toUpperCase()
          : '#';
      final key = RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(contact);
    }
    // Sort keys alphabetically, with '#' at the end
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  /// Build a flat list of section headers + contact items for ListView.builder.
  void _rebuildFlatList() {
    final grouped = _groupContacts();
    final items = <_ListItem>[];
    final indices = <String, int>{};

    for (final entry in grouped.entries) {
      indices[entry.key] = items.length;
      items.add(_ListItem(type: _ListItemType.header, letter: entry.key));
      for (final contact in entry.value) {
        items.add(_ListItem(type: _ListItemType.contact, contact: contact));
      }
    }

    _flatItems = items;
    _sectionIndices = indices;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 28,
          right: 18,
        ),
        child: FloatingActionButton(
          onPressed: _addContact,
          child: const Icon(Icons.add_rounded, size: 34),
          tooltip: 'Add Contact',
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(theme, colorScheme),
            // Search bar
            _buildSearchBar(colorScheme),
            // Contact count
            if (!_isLoading && !_permissionDenied)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  '${_filteredContacts.length} contacts',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Contact list
            Expanded(child: _buildBody(theme, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
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
                      MyContactsColors.cFF1B98E0.withValues(alpha: 0.7),
                      colorScheme.primary.withValues(alpha: 0.5),
                      colorScheme.tertiary.withValues(alpha: 0.4),
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
                  Icons.contacts_rounded,
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
                  'Smart Contacts',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MyContactsColors.white,
                  ),
                ),
              ),
              Text(
                'All your people, one place',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _isHeaderRefreshing ? null : _refreshFromHeader,
              icon: _isHeaderRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: colorScheme.primary),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withValues(
              alpha: _isSearching ? 0.4 : 0.0,
            ),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _isSearching = value.isNotEmpty);
            // Debounce: avoid rebuilding 700+ item list on every keystroke
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 200), () {
              _filterContacts(value);
            });
          },
          decoration: InputDecoration(
            hintText: 'Search contacts...',
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      _debounce?.cancel();
                      _searchController.clear();
                      _filterContacts('');
                      setState(() => _isSearching = false);
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return _buildLoadingState(colorScheme);
    }
    if (_permissionDenied) {
      return _buildPermissionDenied(theme, colorScheme);
    }
    if (_filteredContacts.isEmpty) {
      return _buildEmptyState(theme, colorScheme);
    }
    return _buildContactList(theme, colorScheme);
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    // Shimmer skeleton — shows placeholder rows so the user sees instant structure
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: 12,
      itemBuilder: (context, index) {
        // Every 4th item is a section header placeholder
        if (index % 5 == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                _shimmerBox(32, 32, 8, colorScheme),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              _shimmerCircle(52, colorScheme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(14, 140 + (index % 3) * 30.0, 6, colorScheme),
                    const SizedBox(height: 8),
                    _shimmerBox(10, 100, 4, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(
    double height,
    double width,
    double radius,
    ColorScheme colorScheme,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: value * 0.08),
                colorScheme.tertiary.withValues(alpha: value * 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _shimmerCircle(double size, ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                colorScheme.primary.withValues(alpha: value * 0.12),
                colorScheme.tertiary.withValues(alpha: value * 0.06),
              ],
            ),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _buildPermissionDenied(ThemeData theme, ColorScheme colorScheme) {
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
                    colorScheme.error.withValues(alpha: 0.15),
                    colorScheme.errorContainer.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 56,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Permission Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please grant contacts permission to see your contacts here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _fetchContacts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
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
                    colorScheme.primaryContainer.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSearching
                    ? Icons.search_off_rounded
                    : Icons.person_off_rounded,
                size: 56,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isSearching ? 'No Results' : 'No Contacts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSearching
                  ? 'Try searching with a different name'
                  : 'Your contact list is empty',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToSection(String letter) {
    final targetIndex = _sectionIndices[letter];
    if (targetIndex == null) return;

    // Calculate pixel offset: sum heights of all items before this index
    double offset = 0;
    for (int i = 0; i < targetIndex; i++) {
      offset += _flatItems[i].type == _ListItemType.header
          ? _sectionHeaderHeight
          : _contactTileHeight;
    }

    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildContactList(ThemeData theme, ColorScheme colorScheme) {
    if (_flatItems.isEmpty) _rebuildFlatList();

    final alphabet = _sectionIndices.keys.where((k) => k != '#').toList()
      ..sort();

    return Row(
      children: [
        // Main list — lazy via ListView.builder
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchContacts,
            color: colorScheme.primary,
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _flatItems.length,
              itemExtentBuilder: (index, __) {
                return _flatItems[index].type == _ListItemType.header
                    ? _sectionHeaderHeight
                    : _contactTileHeight;
              },
              itemBuilder: (context, index) {
                final item = _flatItems[index];
                if (item.type == _ListItemType.header) {
                  return _buildSectionHeader(item.letter!, colorScheme);
                }
                return _buildContactTile(item.contact!, theme, colorScheme);
              },
            ),
          ),
        ),
        // Alphabet sidebar
        if (!_isSearching && _filteredContacts.length > 10)
          SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: alphabet
                    .map(
                      (letter) => Expanded(
                        child: GestureDetector(
                          onTap: () => _scrollToSection(letter),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String letter, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.2),
                  colorScheme.tertiary.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
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

  Widget _buildContactTile(
    Contact contact,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    final isFav = _prefsService.isFavourite(contact.id);

    return Dismissible(
      key: ValueKey('contact-${contact.id}'),
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
      confirmDismiss: (direction) async {
        if (phone.isEmpty) return false;
        if (direction == DismissDirection.startToEnd) {
          await _prefsService.addRecent(
            contact.id,
            contact.displayName,
            'call',
          );
          await _makeCall(phone);
        } else {
          await _prefsService.addRecent(
            contact.id,
            contact.displayName,
            'message',
          );
          await _sendSms(phone);
        }
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          elevation: 0.5,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, _, _) =>
                      ContactDetailScreen(contact: contact),
                  transitionsBuilder: (_, animation, _, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  ContactAvatar(contact: contact, radius: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.displayName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty &&
                            _prefsService.getShowPhoneInList()) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await _prefsService.toggleFavourite(contact.id);
                      setState(() {});
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        key: ValueKey(isFav),
                        color: isFav
                            ? MyContactsColors.cFFFFA62E
                            : colorScheme.onSurface.withValues(alpha: 0.18),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helper types for flat list ───

enum _ListItemType { header, contact }

class _ListItem {
  final _ListItemType type;
  final String? letter; // for headers
  final Contact? contact; // for contact rows

  _ListItem({required this.type, this.letter, this.contact});
}
