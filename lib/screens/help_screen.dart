import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sections = <_HelpSection>[
      const _HelpSection(
        title: 'Navigation',
        subtitle: 'Main tabs at the bottom',
        icon: Icons.space_dashboard_rounded,
        color: MyContactsColors.cFF1D4ED8,
        items: [
          _HelpItem(
            title: 'Contacts',
            description: 'Browse all contacts, use search, and open full contact details.',
          ),
          _HelpItem(
            title: 'Favourites',
            description: 'Quick access to contacts you have starred.',
          ),
          _HelpItem(
            title: 'Recents',
            description: 'Review recent calls/messages and frequently called contacts.',
          ),
          _HelpItem(
            title: 'Smart',
            description: 'View suggestions, duplicate detection, groups, insights, and cleanup tips.',
          ),
          _HelpItem(
            title: 'Settings',
            description: 'Customize app behavior, appearance, and data tools.',
          ),
        ],
      ),
      const _HelpSection(
        title: 'Contacts Screen',
        subtitle: 'Finding and organizing contacts',
        icon: Icons.contacts_rounded,
        color: MyContactsColors.cFF0F766E,
        items: [
          _HelpItem(
            title: 'Search',
            description: 'Search by contact name or phone number.',
          ),
          _HelpItem(
            title: 'Alphabet Index',
            description: 'Jump quickly to any letter in the contacts list.',
          ),
          _HelpItem(
            title: 'Add Contact',
            description: 'Use the floating plus button to create a new contact.',
          ),
        ],
      ),
      const _HelpSection(
        title: 'Contact Details',
        subtitle: 'Actions for a selected contact',
        icon: Icons.person_pin_rounded,
        color: MyContactsColors.cFFB45309,
        items: [
          _HelpItem(
            title: 'Quick Actions',
            description: 'Call, fake call, message, WhatsApp, email, and share.',
          ),
          _HelpItem(
            title: 'Edit Contact',
            description: 'Update name, numbers, email, groups, notes, and other fields.',
          ),
          _HelpItem(
            title: 'Favourite',
            description: 'Star or unstar a contact from the details header.',
          ),
          _HelpItem(
            title: 'Call Recordings',
            description: 'View and play matched recordings linked to the contact.',
          ),
        ],
      ),
      const _HelpSection(
        title: 'Smart Tab',
        subtitle: 'Analysis and cleanup tools',
        icon: Icons.psychology_rounded,
        color: MyContactsColors.cFF7C3AED,
        items: [
          _HelpItem(
            title: 'Suggestions',
            description: 'Actionable tips like reconnect, birthdays, and profile completion.',
          ),
          _HelpItem(
            title: 'Duplicates',
            description: 'Find and merge likely duplicate contacts.',
          ),
          _HelpItem(
            title: 'Groups',
            description: 'Open clickable group tiles to view matching contact lists.',
          ),
          _HelpItem(
            title: 'Insights',
            description: 'See quality metrics and data completeness trends.',
          ),
          _HelpItem(
            title: 'Cleanup',
            description: 'Identify low-quality or outdated contact data to improve.',
          ),
        ],
      ),
      const _HelpSection(
        title: 'Settings Options',
        subtitle: 'Customize app behavior',
        icon: Icons.tune_rounded,
        color: MyContactsColors.cFF334155,
        items: [
          _HelpItem(title: 'Theme', description: 'Choose light, dark, or system mode.'),
          _HelpItem(title: 'Accent Color', description: 'Apply your preferred app color.'),
          _HelpItem(title: 'Show Phone in List', description: 'Show or hide phone number in contact rows.'),
          _HelpItem(title: 'Auto Attend Fake Calls', description: 'Auto-answer fake calls after a short delay.'),
          _HelpItem(title: 'Sort Order', description: 'Sort contacts by first name or last name.'),
          _HelpItem(title: 'Default Tab', description: 'Choose which tab opens at app start.'),
          _HelpItem(title: 'Call Recordings Folder', description: 'Set or reset custom folder for call recordings.'),
          _HelpItem(title: 'Clear Recent History', description: 'Delete all recent interaction history.'),
          _HelpItem(title: 'Clear All Favourites', description: 'Remove all starred contacts quickly.'),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.95),
                      colorScheme.tertiary.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: MyContactsColors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: MyContactsColors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.help_center_rounded,
                                color: MyContactsColors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Help Center',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: MyContactsColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Everything you can do in Smart Contacts, explained clearly.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: MyContactsColors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                children: sections
                    .map((section) => _buildHelpSectionCard(section, theme, colorScheme))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSectionCard(
    _HelpSection section,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: section.color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: section.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(section.icon, color: section.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        section.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...section.items.asMap().entries.map((entry) {
              final isLast = entry.key == section.items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: section.color.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.value.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.18),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _HelpSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_HelpItem> items;

  const _HelpSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _HelpItem {
  final String title;
  final String description;

  const _HelpItem({required this.title, required this.description});
}
