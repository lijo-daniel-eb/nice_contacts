import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';

class ContactDetailScreen extends StatelessWidget {
  final Contact contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Gradient App Bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.primary,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // Avatar
                      Hero(
                        tag: 'avatar-${contact.id}',
                        child: ContactAvatar(
                          contact: contact,
                          radius: 52,
                          fontSize: 36,
                          showBorder: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Name
                      Text(
                        contact.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      if (contact.organizations.isNotEmpty)
                        Text(
                          contact.organizations.first.company,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: const Color(0xFF4CAF50),
                    ),
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.message_rounded,
                      label: 'Message',
                      color: const Color(0xFF2196F3),
                    ),
                  if (contact.emails.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.email_rounded,
                      label: 'Email',
                      color: const Color(0xFFFF9800),
                    ),
                  _buildQuickAction(
                    context,
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: colorScheme.tertiary,
                  ),
                ],
              ),
            ),
          ),

          // Contact Info Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  // Phone numbers
                  if (contact.phones.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Phone Numbers',
                      icon: Icons.phone_rounded,
                      items: contact.phones
                          .map(
                            (p) => _InfoItem(
                              label: _phoneLabel(p.label),
                              value: p.number,
                            ),
                          )
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Emails
                  if (contact.emails.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Email Addresses',
                      icon: Icons.email_rounded,
                      items: contact.emails
                          .map(
                            (e) => _InfoItem(
                              label: _emailLabel(e.label),
                              value: e.address,
                            ),
                          )
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Addresses
                  if (contact.addresses.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Addresses',
                      icon: Icons.location_on_rounded,
                      items: contact.addresses
                          .map(
                            (a) => _InfoItem(
                              label: _addressLabel(a.label),
                              value: a.address,
                            ),
                          )
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Organizations
                  if (contact.organizations.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Organization',
                      icon: Icons.business_rounded,
                      items: contact.organizations
                          .map(
                            (o) => _InfoItem(
                              label: o.title.isNotEmpty ? o.title : 'Company',
                              value: o.company,
                            ),
                          )
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Notes
                  if (contact.notes.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Notes',
                      icon: Icons.note_rounded,
                      items: contact.notes
                          .map((n) => _InfoItem(label: 'Note', value: n.note))
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Card items
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: item.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied "${item.value}"'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.value,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _phoneLabel(PhoneLabel label) {
    return switch (label) {
      PhoneLabel.mobile => 'Mobile',
      PhoneLabel.work => 'Work',
      PhoneLabel.home => 'Home',
      PhoneLabel.main => 'Main',
      PhoneLabel.pager => 'Pager',
      PhoneLabel.other => 'Other',
      _ => 'Phone',
    };
  }

  String _emailLabel(EmailLabel label) {
    return switch (label) {
      EmailLabel.home => 'Home',
      EmailLabel.work => 'Work',
      EmailLabel.other => 'Other',
      _ => 'Email',
    };
  }

  String _addressLabel(AddressLabel label) {
    return switch (label) {
      AddressLabel.home => 'Home',
      AddressLabel.work => 'Work',
      AddressLabel.other => 'Other',
      _ => 'Address',
    };
  }
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem({required this.label, required this.value});
}
