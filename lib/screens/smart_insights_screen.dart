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
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();
  late TabController _tabController;

  List<Contact> _contacts = [];
  bool _isLoading = true;

  // Cached results
  List<DuplicateGroup> _duplicates = [];
  Map<String, SmartGroup> _smartGroups = {};
  ContactInsights? _insights;
  List<SuggestedAction> _suggestions = [];
  CleanupReport? _cleanupReport;
  List<RankedContact> _rankedContacts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _repo.addListener(_onRepoUpdated);
    _loadData();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdated);
    _tabController.dispose();
    super.dispose();
  }

  bool _analysisRunning = false;

  void _onRepoUpdated() {
    if (mounted && _repo.hasLoaded && !_analysisRunning) _loadData();
  }

  Future<void> _loadData() async {
    if (_analysisRunning) return;
    _analysisRunning = true;

    await _repo.ensureLoaded();
    final contacts = _repo.contacts;
    if (contacts.isEmpty) {
      _analysisRunning = false;
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Run heavy analysis off the main thread
    final results = await _analyzeInBackground(contacts);

    _analysisRunning = false;
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _duplicates = results.duplicates;
        _smartGroups = results.smartGroups;
        _insights = results.insights;
        _suggestions = _intelligence.generateSuggestions(contacts);
        _cleanupReport = results.cleanupReport;
        _rankedContacts = _intelligence.rankContactsByImportance(contacts);
        _isLoading = false;
      });
    }
  }

  /// Run CPU-heavy analysis (duplicates, groups, insights, cleanup) off main thread
  /// using a real isolate via compute() — prevents UI jank with 700+ contacts.
  Future<_AnalysisResults> _analyzeInBackground(List<Contact> contacts) async {
    return compute(_runAnalysis, contacts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
                Tab(
                  icon: const Icon(Icons.star_rounded, size: 20),
                  text: 'Important',
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
                        _buildImportantTab(theme, colorScheme),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Insights',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
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
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
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
      SuggestionType.birthday => const Color(0xFFFF6584),
      SuggestionType.completeInfo => const Color(0xFFFFA62E),
      SuggestionType.addToFavourites => const Color(0xFF6C63FF),
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
              color: const Color(0xFFFF6584).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF6584),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Found ${_duplicates.length} potential duplicate group${_duplicates.length > 1 ? 's' : ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF6584),
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
          ],
        ),
      ),
    );
  }

  Color _getSimilarityColor(double score) {
    if (score >= 0.9) return const Color(0xFFFF4444);
    if (score >= 0.8) return const Color(0xFFFF6584);
    return const Color(0xFFFFA62E);
  }

  // ─────────────────────────────────────────────
  //  SMART GROUPS TAB
  // ─────────────────────────────────────────────

  Widget _buildGroupsTab(ThemeData theme, ColorScheme colorScheme) {
    if (_smartGroups.isEmpty) {
      return _buildEmptyState(
        icon: Icons.category_rounded,
        title: 'No groups found',
        subtitle: 'Contacts will be auto-categorized based on their info.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _smartGroups.entries.map((entry) {
            return _buildGroupChip(entry.value, colorScheme);
          }).toList(),
        ),
        const SizedBox(height: 20),
        // Expanded group lists
        ..._smartGroups.entries.map((entry) {
          return _buildGroupSection(entry.value, theme, colorScheme);
        }),
      ],
    );
  }

  Widget _buildGroupChip(SmartGroup group, ColorScheme colorScheme) {
    final color = _groupColor(group.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(group.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '${group.name} (${group.contacts.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(
    SmartGroup group,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final color = _groupColor(group.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(group.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                group.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${group.contacts.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          group.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        ...group.contacts
            .take(5)
            .map(
              (contact) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: ContactAvatar(contact: contact, radius: 18),
                title: Text(
                  contact.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: contact.phones.isNotEmpty
                    ? Text(
                        contact.phones.first.number,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      )
                    : null,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  size: 20,
                ),
                onTap: () => _navigateToContact(contact),
              ),
            ),
        if (group.contacts.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '  +${group.contacts.length - 5} more',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const Divider(height: 24),
      ],
    );
  }

  Color _groupColor(String name) {
    return switch (name) {
      'Work' => const Color(0xFF6C63FF),
      'Personal' => const Color(0xFF4ECDC4),
      'Family' => const Color(0xFFFF6584),
      'Social' => const Color(0xFFFFA62E),
      _ => const Color(0xFF9E9E9E),
    };
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
        const Color(0xFF6C63FF),
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
        const Color(0xFFFF6584),
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

  // ─────────────────────────────────────────────
  //  IMPORTANT CONTACTS TAB
  // ─────────────────────────────────────────────

  Widget _buildImportantTab(ThemeData theme, ColorScheme colorScheme) {
    if (_rankedContacts.isEmpty) {
      return _buildEmptyState(
        title: 'No Rankings Yet',
        subtitle: 'Interact with contacts to build importance rankings',
        icon: Icons.stars_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        _buildImportanceSummaryCard(theme, colorScheme),
        const SizedBox(height: 16),
        // Top contacts list
        ...List.generate(
          _rankedContacts.length.clamp(0, 20),
          (index) => _buildRankedContactCard(
            _rankedContacts[index],
            index + 1,
            theme,
            colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildImportanceSummaryCard(ThemeData theme, ColorScheme colorScheme) {
    final top = _rankedContacts.length;
    final avgScore = top > 0
        ? _rankedContacts.fold<double>(0, (sum, r) => sum + r.importanceScore) /
              top
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.2),
            const Color(0xFFFFA500).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFD700),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Contacts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$top ranked contacts \u2022 Avg score: ${avgScore.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedContactCard(
    RankedContact ranked,
    int position,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final medalColor = switch (position) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => colorScheme.onSurface.withValues(alpha: 0.3),
    };

    final scoreColor = ranked.importanceScore >= 70
        ? Colors.green
        : ranked.importanceScore >= 40
        ? Colors.orange
        : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: position <= 3
            ? Border.all(color: medalColor.withValues(alpha: 0.4))
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToContact(ranked.contact),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Position badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: medalColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$position',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: medalColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ContactAvatar(contact: ranked.contact, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ranked.contact.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ranked.isFavourite) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Colors.red.shade400,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      children: ranked.reasons
                          .take(3)
                          .map(
                            (r) => Text(
                              r,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ranked.importanceScore.round().toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
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
