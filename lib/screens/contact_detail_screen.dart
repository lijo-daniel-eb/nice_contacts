import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/screens/edit_contact_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _prefsService = PreferencesService();
  final _repo = ContactsRepository();
  late bool _isFavourite;
  late Contact _currentContact;

  Contact get contact => _currentContact;

  @override
  void initState() {
    super.initState();
    _currentContact = widget.contact;
    _isFavourite = _prefsService.isFavourite(contact.id);
    _repo.addListener(_onRepoUpdated);
    // Kick off high-res photo load
    _repo.getHighResPhoto(contact.id);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdated);
    super.dispose();
  }

  void _onRepoUpdated() {
    if (!mounted) return;
    // Stop listening once the high-res photo is loaded
    if (_repo.hasHighResPhoto(contact.id)) {
      _repo.removeListener(_onRepoUpdated);
    }
    setState(() {});
  }

  Future<void> _editContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditContactScreen(contact: contact)),
    );

    if (!mounted) return;

    if (result == 'deleted') {
      // Contact was deleted — pop back to the list
      Navigator.pop(context, 'deleted');
      return;
    }

    if (result is Contact) {
      setState(() {
        _currentContact = result;
      });
    }
  }

  Future<void> _makeCall(String number) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'call');
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendSms(String number) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'message');
    final uri = Uri(scheme: 'sms', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'email');
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String number) async {
    await _prefsService.addRecent(contact.id, contact.displayName, 'whatsapp');
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    // Try opening directly in WhatsApp app first
    final appUri = Uri.parse('whatsapp://send?phone=$cleanNumber');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web link
      final webUri = Uri.parse('https://wa.me/$cleanNumber');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _shareContact() async {
    final buffer = StringBuffer();
    buffer.writeln(contact.displayName);
    for (final phone in contact.phones) {
      buffer.writeln('Phone: ${phone.number}');
    }
    for (final email in contact.emails) {
      buffer.writeln('Email: ${email.address}');
    }
    if (contact.organizations.isNotEmpty) {
      buffer.writeln('Company: ${contact.organizations.first.company}');
    }
    await Share.share(buffer.toString());
  }

  Future<void> _toggleFavourite() async {
    await _prefsService.toggleFavourite(contact.id);
    setState(() {
      _isFavourite = !_isFavourite;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavourite
                ? '${contact.displayName} added to favourites'
                : '${contact.displayName} removed from favourites',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Build the header with either a full-bleed profile photo or gradient + avatar.
  Widget _buildHeaderBackground(ThemeData theme, ColorScheme colorScheme) {
    // Try high-res photo first, then thumbnail, then inline thumbnail.
    final Uint8List? photo =
        _repo.getHighResPhoto(contact.id) ??
        _repo.getThumbnail(contact.id) ??
        contact.thumbnail;
    final hasPhoto = photo != null && photo.isNotEmpty;

    final primaryColor = ContactAvatar.colorFromName(contact.displayName);

    if (hasPhoto) {
      // Full-bleed photo header
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(photo, fit: BoxFit.cover, width: double.infinity),
          // Dark gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.65),
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
          // Name and company at the bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (contact.organizations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact.organizations.first.company,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      shadows: [
                        Shadow(
                          blurRadius: 6,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // Fallback: gradient + avatar (no photo available)
    return Container(
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
    );
  }

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
            expandedHeight: 340,
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
            actions: [
              IconButton(
                onPressed: _editContact,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleFavourite,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isFavourite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _isFavourite
                        ? const Color(0xFFFFA62E)
                        : Colors.white,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                onPressed: _shareContact,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderBackground(theme, colorScheme),
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
                      onTap: () => _makeCall(contact.phones.first.number),
                    ),
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.message_rounded,
                      label: 'Message',
                      color: const Color(0xFF2196F3),
                      onTap: () => _sendSms(contact.phones.first.number),
                    ),
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: FontAwesomeIcons.whatsapp,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => _openWhatsApp(contact.phones.first.number),
                    ),
                  if (contact.emails.isNotEmpty)
                    _buildQuickAction(
                      context,
                      icon: Icons.email_rounded,
                      label: 'Email',
                      color: const Color(0xFFFF9800),
                      onTap: () => _sendEmail(contact.emails.first.address),
                    ),
                  _buildQuickAction(
                    context,
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: colorScheme.tertiary,
                    onTap: _shareContact,
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
                  // Phone numbers with call/message actions
                  if (contact.phones.isNotEmpty)
                    _buildPhoneCard(
                      context,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),

                  // Emails with send action
                  if (contact.emails.isNotEmpty)
                    _buildEmailCard(
                      context,
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

                  // Websites
                  if (contact.websites.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Websites',
                      icon: Icons.language_rounded,
                      items: contact.websites
                          .map((w) => _InfoItem(label: 'Website', value: w.url))
                          .toList(),
                      colorScheme: colorScheme,
                      theme: theme,
                      onItemTap: (item) async {
                        var url = item.value;
                        if (!url.startsWith('http')) url = 'https://$url';
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),

                  // Events (birthdays, anniversaries)
                  if (contact.events.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Events',
                      icon: Icons.cake_rounded,
                      items: contact.events.map((e) {
                        final label = switch (e.label) {
                          EventLabel.birthday => 'Birthday',
                          EventLabel.anniversary => 'Anniversary',
                          _ => 'Event',
                        };
                        final dateStr =
                            '${e.month}/${e.day}'
                            '${e.year != null ? '/${e.year}' : ''}';
                        return _InfoItem(label: label, value: dateStr);
                      }).toList(),
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

  Widget _buildPhoneCard(
    BuildContext context, {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(Icons.phone_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Phone Numbers',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...contact.phones.asMap().entries.map((entry) {
            final phone = entry.value;
            final isLast = entry.key == contact.phones.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () {
                            Clipboard.setData(
                              ClipboardData(text: phone.number),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${phone.number}"'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _phoneLabel(phone.label),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone.number,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _iconActionButton(
                        icon: Icons.call_rounded,
                        color: const Color(0xFF4CAF50),
                        tooltip: 'Call',
                        onTap: () => _makeCall(phone.number),
                      ),
                      const SizedBox(width: 8),
                      _iconActionButton(
                        icon: Icons.message_rounded,
                        color: const Color(0xFF2196F3),
                        tooltip: 'Message',
                        onTap: () => _sendSms(phone.number),
                      ),
                      const SizedBox(width: 8),
                      _iconActionButton(
                        icon: FontAwesomeIcons.whatsapp,
                        color: const Color(0xFF25D366),
                        tooltip: 'WhatsApp',
                        onTap: () => _openWhatsApp(phone.number),
                      ),
                    ],
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

  Widget _buildEmailCard(
    BuildContext context, {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(Icons.email_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Email Addresses',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...contact.emails.asMap().entries.map((entry) {
            final email = entry.value;
            final isLast = entry.key == contact.emails.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () {
                            Clipboard.setData(
                              ClipboardData(text: email.address),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${email.address}"'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _emailLabel(email.label),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email.address,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _iconActionButton(
                        icon: Icons.send_rounded,
                        color: const Color(0xFFFF9800),
                        tooltip: 'Send email',
                        onTap: () => _sendEmail(email.address),
                      ),
                    ],
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

  Widget _iconActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
    required ColorScheme colorScheme,
    required ThemeData theme,
    void Function(_InfoItem item)? onItemTap,
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
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: onItemTap != null ? () => onItemTap(item) : null,
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
