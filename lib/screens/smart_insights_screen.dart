import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/screens/contact_detail_screen.dart';
import 'package:my_contacts/services/contact_intelligence_service.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class SmartInsightsScreen extends StatefulWidget {
  const SmartInsightsScreen({super.key});

  @override
  State<SmartInsightsScreen> createState() => _SmartInsightsScreenState();
}

class _SmartInsightsScreenState extends State<SmartInsightsScreen>
    with SingleTickerProviderStateMixin {
  final _intelligence = ContactIntelligenceService();
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Found ${_duplicates.length} potential duplicate group${_duplicates.length > 1 ? 's' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF6B35),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              onPressed: _isMergingDuplicates
                                  ? null
                                  : _mergeAllDuplicatesBySameNumber,
                              icon: _isMergingDuplicates
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.merge_type_rounded),
                              label: const Text('Merge All'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final group = _duplicates[index - 1];
        return _buildDuplicateCard(group, index, theme, colorScheme);
      },
    );
  }

  Future<void> _mergeAllDuplicatesBySameNumber() async {
    await _mergeDuplicatesBySameNumberForGroups(
      _duplicates,
      noDuplicatesMessage: 'No same-number duplicates found to merge',
      confirmContent:
          'This will merge contacts across all duplicate groups when they share the same phone number and delete duplicate entries. Continue?',
    );
  }

  Widget _buildDuplicateCard(
    DuplicateGroup group,
    int index,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final percentage = (group.similarityScore * 100).toInt();
    final canMergeBySameNumber = _hasSameNumberDuplicates(group);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getSimilarityColor(
                      group.similarityScore,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$percentage% match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getSimilarityColor(group.similarityScore),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...group.contacts.map(
              (contact) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _navigateToContact(contact),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ContactAvatar(contact: contact, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (contact.phones.isNotEmpty)
                                Text(
                                  contact.phones.first.number,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (canMergeBySameNumber)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isMergingDuplicates
                        ? null
                        : () => _mergeDuplicatesBySameNumber(group),
                    icon: _isMergingDuplicates
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.merge_type_rounded),
                    label: const Text('Merge Same Number'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, colorScheme),
            TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withValues(
                alpha: 0.5,
              ),
              indicatorColor: const Color(0xFF4ECDC4),
              indicatorWeight: 3,
              dividerHeight: 0,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  text: 'Suggestions',
                ),
                Tab(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  text: 'Duplicates',
                ),
                Tab(
                  icon: const Icon(Icons.category_rounded, size: 20),
                  text: 'Groups',
                ),
                Tab(
                  icon: const Icon(Icons.insights_rounded, size: 20),
                  text: 'Insights',
                ),
                Tab(
                  icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                  text: 'Cleanup',
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSuggestionsTab(theme, colorScheme),
                        _buildDuplicatesTab(theme, colorScheme),
                        _buildGroupsTab(theme, colorScheme),
                        _buildInsightsTab(theme, colorScheme),
                        _buildCleanupTab(theme, colorScheme),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                    colors: [Color(0xCC1B98E0), Color(0x994ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B98E0).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
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
                  colors: [Color(0xFF1B98E0), Color(0xFF4ECDC4)],
                ).createShader(bounds),
                child: Text(
                  'Smart Insights',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'AI-powered contact analysis',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadData();
              },
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4ECDC4)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SUGGESTIONS TAB
  // ─────────────────────────────────────────────

  Widget _buildSuggestionsTab(ThemeData theme, ColorScheme colorScheme) {
    if (_suggestions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'No suggestions yet',
        subtitle:
            'Start using the app to get personalized suggestions.\nCall, message, and favourite contacts to see recommendations.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return _buildSuggestionCard(suggestion, theme, colorScheme);
      },
    );
  }

  Widget _buildSuggestionCard(
    SuggestedAction suggestion,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final iconData = switch (suggestion.type) {
      SuggestionType.reconnect => Icons.phone_callback_rounded,
      SuggestionType.birthday => Icons.cake_rounded,
      SuggestionType.completeInfo => Icons.edit_note_rounded,
      SuggestionType.addToFavourites => Icons.star_rounded,
    };

    final color = switch (suggestion.type) {
      SuggestionType.reconnect => const Color(0xFF4CAF50),
      SuggestionType.birthday => const Color(0xFFFF6B35),
      SuggestionType.completeInfo => const Color(0xFFFFA62E),
      SuggestionType.addToFavourites => const Color(0xFF1B98E0),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleSuggestion(suggestion),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.subtitle,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSuggestion(SuggestedAction suggestion) {
    switch (suggestion.type) {
      case SuggestionType.reconnect:
      case SuggestionType.birthday:
      case SuggestionType.completeInfo:
        _navigateToContact(suggestion.contact);
        break;
      case SuggestionType.addToFavourites:
        _prefsService.addFavourite(suggestion.contact.id);
        setState(() {
          _suggestions = _intelligence.generateSuggestions(_contacts);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${suggestion.contact.displayName} added to favourites',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        break;
    }
  }

  // ─────────────────────────────────────────────
  //  DUPLICATES TAB
  // ─────────────────────────────────────────────

  Widget _buildDuplicatesTab(ThemeData theme, ColorScheme colorScheme) {
    if (_duplicates.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No duplicates found',
        subtitle: 'Your contacts are clean! No potential duplicates detected.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _duplicates.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 0,
              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF6B35),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Found ${_duplicates.length} potential duplicate group${_duplicates.length > 1 ? 's' : ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final group = _duplicates[index - 1];
        return _buildDuplicateCard(group, index, theme, colorScheme);
      },
    );
  }

  Widget _buildDuplicateCard(
    DuplicateGroup group,
    int index,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final percentage = (group.similarityScore * 100).toInt();
    final canMergeBySameNumber = _hasSameNumberDuplicates(group);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getSimilarityColor(
                      group.similarityScore,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$percentage% match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getSimilarityColor(group.similarityScore),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...group.contacts.map(
              (contact) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _navigateToContact(contact),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ContactAvatar(contact: contact, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (contact.phones.isNotEmpty)
                                Text(
                                  contact.phones.first.number,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (canMergeBySameNumber)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isMergingDuplicates
                        ? null
                        : () => _mergeDuplicatesBySameNumber(group),
                    icon: _isMergingDuplicates
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.merge_type_rounded),
                    label: const Text('Merge Same Number'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasSameNumberDuplicates(DuplicateGroup group) {
    final seen = <String>{};
    for (final contact in group.contacts) {
      for (final phone in contact.phones) {
        final key = _normalizedPhoneMergeKey(phone.number);
        if (key == null) continue;
        if (seen.contains(key)) return true;
        seen.add(key);
      }
    }
    return false;
  }

  Future<void> _mergeDuplicatesBySameNumber(DuplicateGroup group) async {
    await _mergeDuplicatesBySameNumberForGroups(
      [group],
      noDuplicatesMessage: 'No same-number duplicates to merge',
      confirmContent:
          'This will merge contacts that share the same phone number and delete duplicate entries. Continue?',
    );
  }

  Future<void> _mergeDuplicatesBySameNumberForGroups(
    List<DuplicateGroup> groups, {
    required String noDuplicatesMessage,
    required String confirmContent,
  }) async {
    final byNumber = <String, List<Contact>>{};
    for (final group in groups) {
      for (final contact in group.contacts) {
        final keys = contact.phones
            .map((p) => _normalizedPhoneMergeKey(p.number))
            .whereType<String>()
            .toSet();
        for (final key in keys) {
          byNumber.putIfAbsent(key, () => []).add(contact);
        }
      }
    }

    final mergeSets = byNumber.values
        .map((list) => list.toSet().toList())
        .where((list) => list.length > 1)
        .toList();

    if (mergeSets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(noDuplicatesMessage)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge Duplicates'),
        content: Text(confirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isMergingDuplicates = true);
    final deletedIds = <String>{};
    var mergedContacts = 0;

    try {
      for (final mergeList in mergeSets) {
        final active = mergeList
            .where((c) => !deletedIds.contains(c.id))
            .toList();
        if (active.length < 2) continue;

        active.sort((a, b) => _contactDataWeight(b).compareTo(_contactDataWeight(a)));

        Contact primary = await FlutterContacts.getContact(
              active.first.id,
              withProperties: true,
              withPhoto: true,
            ) ??
            active.first;

        var changedPrimary = false;
        for (final secondaryRef in active.skip(1)) {
          if (deletedIds.contains(secondaryRef.id)) continue;

          final secondary = await FlutterContacts.getContact(
                secondaryRef.id,
                withProperties: true,
                withPhoto: true,
              ) ??
              secondaryRef;

          changedPrimary =
              _mergeContactIntoPrimary(primary, secondary) || changedPrimary;
          await FlutterContacts.deleteContact(secondary);
          deletedIds.add(secondary.id);
          mergedContacts++;
        }

        if (changedPrimary) {
          await FlutterContacts.updateContact(primary);
        }
      }

      await _repo.refresh();
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mergedContacts > 0
                ? 'Merged $mergedContacts duplicate contact${mergedContacts > 1 ? 's' : ''}'
                : 'No duplicates were merged',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to merge duplicates: $e')),
      );
    } finally {
      if (mounted) setState(() => _isMergingDuplicates = false);
    }
  }

  int _contactDataWeight(Contact contact) {
    var score = 0;
    score += contact.phones.length * 3;
    score += contact.emails.length * 2;
    score += contact.addresses.length;
    score += contact.organizations.length;
    score += contact.websites.length;
    score += contact.events.length;
    score += contact.notes.length;
    score += contact.socialMedias.length;
    if (contact.photo != null || contact.thumbnail != null) score += 2;
    if (contact.displayName.trim().isNotEmpty) score += 1;
    return score;
  }

  bool _mergeContactIntoPrimary(Contact primary, Contact secondary) {
    var changed = false;

    if (primary.displayName.trim().isEmpty &&
        secondary.displayName.trim().isNotEmpty) {
      primary.name = secondary.name;
      changed = true;
    }

    if (primary.photo == null && secondary.photo != null) {
      primary.photo = secondary.photo;
      changed = true;
    }
    if (primary.thumbnail == null && secondary.thumbnail != null) {
      primary.thumbnail = secondary.thumbnail;
      changed = true;
    }

    changed =
        _appendUnique(
          target: primary.phones,
          source: secondary.phones,
          key: (p) => _normalizedPhoneMergeKey(p.number) ?? p.number,
        ) ||
        changed;
    changed =
        _appendUnique(
          target: primary.emails,
          source: secondary.emails,
          key: (e) => e.address.toLowerCase(),
        ) ||
        changed;
    changed =
        _appendUnique(
          target: primary.addresses,
          source: secondary.addresses,
          key: (a) => a.address.trim().toLowerCase(),
        ) ||
        changed;
    changed =
        _appendUnique(
          target: primary.organizations,
          source: secondary.organizations,
          key: (o) => '${o.company}|${o.title}'.toLowerCase(),
        ) ||
        changed;
    changed =
        _appendUnique(
          target: primary.websites,
          source: secondary.websites,
          key: (w) => w.url.toLowerCase(),
        ) ||
        changed;
    changed =
        _appendUnique(
          target: primary.notes,
          source: secondary.notes,
          key: (n) => n.note.trim().toLowerCase(),
        ) ||
        changed;
    changed =
        _appendUnique(
          target: primary.socialMedias,
          source: secondary.socialMedias,
          key: (s) => '${s.userName}|${s.label.name}'.toLowerCase(),
        ) ||
        changed;

    return changed;
  }

  bool _appendUnique<T>({
    required List<T> target,
    required Iterable<T> source,
    required String Function(T item) key,
  }) {
    var changed = false;
    final existingKeys = target.map(key).toSet();
    for (final item in source) {
      final itemKey = key(item);
      if (existingKeys.contains(itemKey)) continue;
      target.add(item);
      existingKeys.add(itemKey);
      changed = true;
    }
    return changed;
  }

  String? _normalizedPhoneMergeKey(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return null;
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  Color _getSimilarityColor(double score) {
    if (score >= 0.9) return const Color(0xFFFF4444);
    if (score >= 0.8) return const Color(0xFFFF6B35);
    return const Color(0xFFFFA62E);
  }

  // ─────────────────────────────────────────────
  //  SMART GROUPS TAB
  // ─────────────────────────────────────────────

  Widget _buildGroupsTab(ThemeData theme, ColorScheme colorScheme) {
    final groups = _buildCombinedGroups();

    if (groups.isEmpty) {
      return _buildEmptyState(
        icon: Icons.category_rounded,
        title: 'No groups found',
        subtitle: 'Add groups or organization tags in Edit Contact to see tiles here.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupTile(group, theme, colorScheme);
      },
    );
  }

  List<SmartGroup> _buildCombinedGroups() {
    final combined = <SmartGroup>[];
    combined.addAll(_buildAssignedContactGroups());
    combined.addAll(_buildOrganizationGroups());

    combined.sort((a, b) {
      final countCompare = b.contacts.length.compareTo(a.contacts.length);
      if (countCompare != 0) return countCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return combined;
  }

  List<SmartGroup> _buildAssignedContactGroups() {
    final contactsByGroup = <String, List<Contact>>{};
    final groupNameByKey = <String, String>{};

    for (final contact in _contacts) {
      final assigned = _prefsService.getContactGroups(contact.id);
      for (final groupName in assigned) {
        final trimmed = groupName.trim();
        if (trimmed.isEmpty) continue;

        final key = trimmed.toLowerCase();
        groupNameByKey.putIfAbsent(key, () => trimmed);
        contactsByGroup.putIfAbsent(key, () => []);

        final list = contactsByGroup[key]!;
        if (!list.any((c) => c.id == contact.id)) {
          list.add(contact);
        }
      }
    }

    final groups = contactsByGroup.entries.map((entry) {
      final displayName = groupNameByKey[entry.key] ?? entry.key;
      final contacts = entry.value.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      return SmartGroup(
        name: displayName,
        icon: '🏷️',
        contacts: contacts,
        description: 'Group',
      );
    }).toList();

    return groups;
  }

  List<SmartGroup> _buildOrganizationGroups() {
    final contactsByOrg = <String, List<Contact>>{};
    final orgNameByKey = <String, String>{};

    for (final contact in _contacts) {
      final orgNames = <String>{};
      for (final org in contact.organizations) {
        final company = org.company.trim();
        if (company.isEmpty) continue;
        orgNames.add(company);
      }

      for (final orgName in orgNames) {
        final key = orgName.toLowerCase();
        orgNameByKey.putIfAbsent(key, () => orgName);
        contactsByOrg.putIfAbsent(key, () => []);

        final list = contactsByOrg[key]!;
        if (!list.any((c) => c.id == contact.id)) {
          list.add(contact);
        }
      }
    }

    final groups = contactsByOrg.entries.map((entry) {
      final displayName = orgNameByKey[entry.key] ?? entry.key;
      final contacts = entry.value.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      return SmartGroup(
        name: displayName,
        icon: '🏢',
        contacts: contacts,
        description: 'Contacts tagged under $displayName',
      );
    }).toList();

    groups.sort((a, b) {
      final countCompare = b.contacts.length.compareTo(a.contacts.length);
      if (countCompare != 0) return countCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return groups;
  }

  Widget _buildGroupTile(
    SmartGroup group,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final color = _groupColor(group.name);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openGroupContactsList(group, theme, colorScheme),
        child: Ink(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(group.icon, style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFF4A300)),
                    ),
                    child: Text(
                      '${group.contacts.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3B2A00),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGroupContactsList(
    SmartGroup group,
    ThemeData theme,
    ColorScheme colorScheme,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: Text('${group.icon} ${group.name}'),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: group.contacts.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
            itemBuilder: (_, index) {
              final contact = group.contacts[index];
              final subtitle = contact.phones.isNotEmpty
                  ? contact.phones.first.number
                  : contact.emails.isNotEmpty
                  ? contact.emails.first.address
                  : 'No details';

              return ListTile(
                leading: ContactAvatar(contact: contact, radius: 20),
                title: Text(
                  contact.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(routeContext);
                  _navigateToContact(contact);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Color _groupColor(String name) {
    return switch (name) {
      'Work' => const Color(0xFF1B98E0),
      'Personal' => const Color(0xFF4ECDC4),
      'Family' => const Color(0xFFFF6B35),
      'Social' => const Color(0xFFFFA62E),
      _ => _colorFromName(name),
    };
  }

  Color _colorFromName(String name) {
    const palette = [
      Color(0xFF1B98E0),
      Color(0xFF7C3AED),
      Color(0xFF0F766E),
      Color(0xFFB45309),
      Color(0xFFD63031),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFF9800),
    ];

    final hash = name.toLowerCase().runes.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  // ─────────────────────────────────────────────
  //  INSIGHTS TAB
  // ─────────────────────────────────────────────

  Widget _buildInsightsTab(ThemeData theme, ColorScheme colorScheme) {
    if (_insights == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final ins = _insights!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Completeness gauge
        _buildCompletenessCard(ins, theme, colorScheme),
        const SizedBox(height: 16),

        // Stats grid
        _buildStatsGrid(ins, theme, colorScheme),
        const SizedBox(height: 16),

        // Company distribution
        if (ins.companyDistribution.isNotEmpty)
          _buildDistributionCard(
            title: 'Top Companies',
            icon: Icons.business_rounded,
            distribution: ins.companyDistribution,
            theme: theme,
            colorScheme: colorScheme,
          ),
        if (ins.companyDistribution.isNotEmpty) const SizedBox(height: 16),

        // Domain distribution
        if (ins.domainDistribution.isNotEmpty)
          _buildDistributionCard(
            title: 'Email Domains',
            icon: Icons.email_rounded,
            distribution: ins.domainDistribution,
            theme: theme,
            colorScheme: colorScheme,
          ),
        if (ins.domainDistribution.isNotEmpty) const SizedBox(height: 16),

        // Incomplete contacts
        if (ins.incompleteContacts.isNotEmpty)
          _buildIncompleteCard(ins, theme, colorScheme),
      ],
    );
  }

  Widget _buildCompletenessCard(
    ContactInsights ins,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final percentage = (ins.averageCompleteness * 100).toInt();
    final color = percentage >= 70
        ? const Color(0xFF4CAF50)
        : percentage >= 40
        ? const Color(0xFFFFA62E)
        : const Color(0xFFFF4444);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Contact Completeness',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: ins.averageCompleteness,
                      strokeWidth: 10,
                      backgroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.1,
                      ),
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentage%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      Text(
                        'average',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              percentage >= 70
                  ? 'Great! Your contacts are well maintained.'
                  : percentage >= 40
                  ? 'Consider adding more details to your contacts.'
                  : 'Many contacts are missing important info.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    ContactInsights ins,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final stats = [
      _StatItem(
        'Total',
        '${ins.totalContacts}',
        Icons.people_rounded,
        const Color(0xFF1B98E0),
      ),
      _StatItem(
        'With Phone',
        '${ins.withPhone}',
        Icons.phone_rounded,
        const Color(0xFF4CAF50),
      ),
      _StatItem(
        'With Email',
        '${ins.withEmail}',
        Icons.email_rounded,
        const Color(0xFF2196F3),
      ),
      _StatItem(
        'With Company',
        '${ins.withOrganization}',
        Icons.business_rounded,
        const Color(0xFFFFA62E),
      ),
      _StatItem(
        'With Photo',
        '${ins.withPhoto}',
        Icons.photo_camera_rounded,
        const Color(0xFFFF6B35),
      ),
      _StatItem(
        'With Birthday',
        '${ins.withBirthday}',
        Icons.cake_rounded,
        const Color(0xFF4ECDC4),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: stat.color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(stat.icon, color: stat.color, size: 24),
              const SizedBox(height: 6),
              Text(
                stat.value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: stat.color,
                ),
              ),
              Text(
                stat.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDistributionCard({
    required String title,
    required IconData icon,
    required Map<String, int> distribution,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final topItems = distribution.entries.take(5).toList();
    final maxValue = topItems.isEmpty ? 1 : topItems.first.value;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...topItems.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value / maxValue,
                        minHeight: 6,
                        backgroundColor: colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncompleteCard(
    ContactInsights ins,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFA62E).withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFA62E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Incomplete Contacts (${ins.incompleteContacts.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFA62E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These contacts have less than 50% of info filled in.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),
            ...ins.incompleteContacts
                .take(5)
                .map(
                  (contact) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: ContactAvatar(contact: contact, radius: 16),
                    title: Text(
                      contact.displayName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA62E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(_intelligence.completenessScore(contact) * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFA62E),
                        ),
                      ),
                    ),
                    onTap: () => _navigateToContact(contact),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  CLEANUP TAB
  // ─────────────────────────────────────────────

  Widget _buildCleanupTab(ThemeData theme, ColorScheme colorScheme) {
    final report = _cleanupReport;
    if (report == null) {
      return _buildEmptyState(
        title: 'No Data',
        subtitle: 'Unable to analyse contacts',
        icon: Icons.error_outline_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Health score card
        _buildHealthScoreCard(report, theme, colorScheme),
        const SizedBox(height: 16),
        if (report.suggestions.isEmpty)
          _buildEmptyState(
            title: 'All Clean!',
            subtitle: 'Your contacts are in great shape',
            icon: Icons.check_circle_outline_rounded,
          )
        else
          ...report.suggestions.map(
            (s) => _buildCleanupSuggestionCard(s, theme, colorScheme),
          ),
      ],
    );
  }

  Widget _buildHealthScoreCard(
    CleanupReport report,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final percentage = (report.healthScore * 100).round();
    final healthColor = percentage >= 80
        ? Colors.green
        : percentage >= 50
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            healthColor.withValues(alpha: 0.15),
            healthColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: healthColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: report.healthScore,
                    strokeWidth: 8,
                    backgroundColor: healthColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: healthColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Health',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${report.totalContacts} contacts analysed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (report.totalIssues > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${report.totalIssues} issue${report.totalIssues > 1 ? 's' : ''} found',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: healthColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupSuggestionCard(
    CleanupSuggestion suggestion,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final severityColor = switch (suggestion.severity) {
      CleanupSeverity.high => Colors.red,
      CleanupSeverity.medium => Colors.orange,
      CleanupSeverity.low => Colors.blue,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: severityColor.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(suggestion.icon, style: const TextStyle(fontSize: 22)),
          ),
          title: Text(
            suggestion.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  suggestion.severity.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: severityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  suggestion.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          children: [
            ...suggestion.contacts
                .take(10)
                .map(
                  (contact) => ListTile(
                    dense: true,
                    leading: ContactAvatar(contact: contact, radius: 18),
                    title: Text(
                      contact.displayName,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : contact.emails.isNotEmpty
                          ? contact.emails.first.address
                          : 'No details',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    onTap: () => _navigateToContact(contact),
                  ),
                ),
            if (suggestion.contacts.length > 10)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '+ ${suggestion.contacts.length - 10} more',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToContact(Contact contact) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ContactDetailScreen(contact: contact),
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
  }
}

/// Top-level function for compute() — runs in a separate isolate.
/// This avoids blocking the UI thread during heavy O(n²) duplicate detection
/// and contact analysis with 700+ contacts.
_AnalysisResults _runAnalysis(List<Contact> contacts) {
  final intelligence = ContactIntelligenceService();
  final duplicates = intelligence.findDuplicates(contacts);
  final smartGroups = intelligence.categorizeContacts(contacts);
  final insights = intelligence.analyzeContacts(contacts);
  final cleanupReport = intelligence.generateCleanupReport(contacts);

  return _AnalysisResults(
    duplicates: duplicates,
    smartGroups: smartGroups,
    insights: insights,
    cleanupReport: cleanupReport,
  );
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}

class _AnalysisResults {
  final List<DuplicateGroup> duplicates;
  final Map<String, SmartGroup> smartGroups;
  final ContactInsights insights;
  final CleanupReport cleanupReport;

  _AnalysisResults({
    required this.duplicates,
    required this.smartGroups,
    required this.insights,
    required this.cleanupReport,
  });
}
