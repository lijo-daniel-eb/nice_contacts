import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/screens/contact_detail_screen.dart';
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
  final Map<String, GlobalKey> _sectionKeys = {};
  final _prefsService = PreferencesService();
  bool _isSearching = false;
  late AnimationController _animController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
      return;
    }

    // Phase 1: Load contacts with properties only (fast — no image data)
    final contacts = await FlutterContacts.getContacts(withProperties: true);

    setState(() {
      _allContacts = contacts;
      _filteredContacts = _searchController.text.isEmpty
          ? contacts
          : _applyFilter(contacts, _searchController.text);
      _isLoading = false;
    });
    _animController.forward();

    // Phase 2: Load thumbnails in background for avatar display
    final contactsWithThumbs = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: true,
    );

    if (mounted) {
      setState(() {
        _allContacts = contactsWithThumbs;
        _filteredContacts = _searchController.text.isEmpty
            ? contactsWithThumbs
            : _applyFilter(contactsWithThumbs, _searchController.text);
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _applyFilter(_allContacts, query);
    });
  }

  List<Contact> _applyFilter(List<Contact> contacts, String query) {
    if (query.isEmpty) return contacts;
    final search = query.toLowerCase();
    return contacts.where((contact) {
      return contact.displayName.toLowerCase().contains(search);
    }).toList();
  }

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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.contacts_rounded,
              color: colorScheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Contacts',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
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
          IconButton(
            onPressed: () {
              _fetchContacts();
            },
            icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
            tooltip: 'Refresh',
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
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            _filterContacts(value);
            setState(() => _isSearching = value.isNotEmpty);
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading contacts...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
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
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
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
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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
    final key = _sectionKeys[letter];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    }
  }

  Widget _buildContactList(ThemeData theme, ColorScheme colorScheme) {
    final grouped = _groupContacts();
    final alphabet = grouped.keys.where((k) => k != '#').toList()..sort();

    // Ensure section keys exist for all groups
    for (final key in grouped.keys) {
      _sectionKeys.putIfAbsent(key, () => GlobalKey());
    }

    return Row(
      children: [
        // Main list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchContacts,
            color: colorScheme.primary,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries.map((entry) {
                  return _buildSection(
                    entry.key,
                    entry.value,
                    theme,
                    colorScheme,
                  );
                }).toList(),
              ),
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

  Widget _buildSection(
    String letter,
    List<Contact> contacts,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      key: _sectionKeys[letter],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 14,
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
        ),
        // Contacts in this section
        ...contacts.asMap().entries.map((entry) {
          final index = entry.key;
          final contact = entry.value;
          return _buildContactTile(contact, index, theme, colorScheme);
        }),
      ],
    );
  }

  Future<void> _makeCall(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendSms(String number) async {
    final uri = Uri(scheme: 'sms', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildContactTile(
    Contact contact,
    int index,
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
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.call_rounded, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.message_rounded, color: Colors.white, size: 28),
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
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
                        if (phone.isNotEmpty) ...[
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
                    child: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFav
                          ? const Color(0xFFFFA62E)
                          : colorScheme.onSurface.withValues(alpha: 0.2),
                      size: 22,
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
