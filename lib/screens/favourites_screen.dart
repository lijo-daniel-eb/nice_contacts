import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/screens/contact_detail_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/direct_call_service.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => FavouritesScreenState();
}

class FavouritesScreenState extends State<FavouritesScreen>
    with AutomaticKeepAliveClientMixin {
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();
  List<Contact> _favouriteContacts = [];
  bool _isLoading = true;
  bool _isHeaderRefreshing = false;

  /// Call this from outside to refresh the favourites list.
  void refresh() => _loadFavourites();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoUpdated);
    _loadFavourites();
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
      if (mounted) _loadFavourites();
    });
  }

  Future<void> _loadFavourites() async {
    final favIds = _prefsService.getFavourites();
    if (favIds.isEmpty) {
      if (mounted) {
        setState(() {
          _favouriteContacts = [];
          _isLoading = false;
        });
      }
      return;
    }

    // Use cached contacts from the shared repository
    await _repo.ensureLoaded();
    final allContacts = _repo.contacts;

    final favContacts = allContacts
        .where((c) => favIds.contains(c.id))
        .toList();
    favContacts.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    if (mounted) {
      setState(() {
        _favouriteContacts = favContacts;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFromHeader() async {
    if (_isHeaderRefreshing) return;
    setState(() => _isHeaderRefreshing = true);
    try {
      await _loadFavourites();
    } finally {
      if (!mounted) return;
      setState(() => _isHeaderRefreshing = false);
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
                    colors: [MyContactsColors.cCCFFA62E, MyContactsColors.c99FF6B35],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MyContactsColors.white.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MyContactsColors.cFFFFA62E.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
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
                  colors: [MyContactsColors.cFFFFA62E, MyContactsColors.cFFFF6B35],
                ).createShader(bounds),
                child: Text(
                  'Favourites',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MyContactsColors.white,
                  ),
                ),
              ),
              Text(
                '${_favouriteContacts.length} starred contacts',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: MyContactsColors.cFFFFA62E.withValues(alpha: 0.08),
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
                        color: MyContactsColors.cFFFFA62E,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: MyContactsColors.cFFFFA62E,
                    ),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_favouriteContacts.isEmpty) {
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
                      MyContactsColors.cFFFFA62E.withValues(alpha: 0.18),
                      MyContactsColors.cFFFF6B35.withValues(alpha: 0.06),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_outline_rounded,
                  size: 56,
                  color: MyContactsColors.cFFFFA62E.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Favourites Yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Star contacts to see them here.\nTap the star icon on any contact.',
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

    return RefreshIndicator(
      onRefresh: _loadFavourites,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _favouriteContacts.length,
        itemBuilder: (context, index) {
          final contact = _favouriteContacts[index];
          return _buildFavouriteTile(contact, theme, colorScheme);
        },
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

  Widget _buildFavouriteTile(
    Contact contact,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';

    return Dismissible(
      key: ValueKey('fav-${contact.id}'),
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
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContactDetailScreen(contact: contact),
                ),
              );
              _loadFavourites();
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
                  IconButton(
                    icon: const Icon(
                      Icons.star_rounded,
                      color: MyContactsColors.cFFFFA62E,
                    ),
                    onPressed: () async {
                      await _prefsService.toggleFavourite(contact.id);
                      _loadFavourites();
                    },
                    tooltip: 'Remove from favourites',
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
