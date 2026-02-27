import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/screens/contact_detail_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';

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
    _repo.removeListener(_onRepoUpdated);
    super.dispose();
  }

  void _onRepoUpdated() {
    if (mounted) _loadFavourites();
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFFA62E), const Color(0xFFFF6584)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Favourites',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
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
          IconButton(
            onPressed: _loadFavourites,
            icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
            tooltip: 'Refresh',
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
                  color: const Color(0xFFFFA62E).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_outline_rounded,
                  size: 56,
                  color: const Color(0xFFFFA62E).withValues(alpha: 0.7),
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

  Widget _buildFavouriteTile(
    Contact contact,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';

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
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
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
                    color: Color(0xFFFFA62E),
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
    );
  }
}
