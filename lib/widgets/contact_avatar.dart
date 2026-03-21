import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/services/contacts_repository.dart';

/// A beautiful contact avatar that shows the contact's photo or initials
/// with a gradient background derived from the contact's name.
///
/// Thumbnails are loaded lazily from [ContactsRepository] and appear with a
/// smooth fade-in once available — no blocking on startup.
class ContactAvatar extends StatefulWidget {
  final Contact contact;
  final double radius;
  final double? fontSize;
  final bool showBorder;

  const ContactAvatar({
    super.key,
    required this.contact,
    this.radius = 24,
    this.fontSize,
    this.showBorder = false,
  });

  /// Generate a consistent color from a string (contact name)
  static Color colorFromName(String name) {
    const colors = [
      MyContactsColors.cFF1B98E0, // Steel Blue
      MyContactsColors.cFFFF6B35, // Burnt Orange
      MyContactsColors.cFF43E97B, // Green
      MyContactsColors.cFFFFA62E, // Orange
      MyContactsColors.cFF00C9FF, // Cyan
      MyContactsColors.cFFF25C54, // Coral Red
      MyContactsColors.cFF2D6CDF, // Royal Blue
      MyContactsColors.cFFD63031, // Strong Red
      MyContactsColors.cFF00BCD4, // Teal
      MyContactsColors.cFFFF5722, // Deep Orange
      MyContactsColors.cFF8BC34A, // Light Green
      MyContactsColors.cFF0A6ABF, // Deep Navy
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }

  static Color _secondaryColorFromName(String name) {
    const colors = [
      MyContactsColors.cFF4DB8F0,
      MyContactsColors.cFFFF8C42,
      MyContactsColors.cFF66F09B,
      MyContactsColors.cFFFFBE5C,
      MyContactsColors.cFF4DD8FF,
      MyContactsColors.cFFFF9255,
      MyContactsColors.cFF5A8FE8,
      MyContactsColors.cFFE17055,
      MyContactsColors.cFF26C6DA,
      MyContactsColors.cFFFF8A65,
      MyContactsColors.cFFAED581,
      MyContactsColors.cFF3A8FD6,
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }

  @override
  State<ContactAvatar> createState() => _ContactAvatarState();
}

class _ContactAvatarState extends State<ContactAvatar> {
  final _repo = ContactsRepository();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _startListeningIfNeeded();
  }

  @override
  void dispose() {
    if (_listening) {
      _repo.removeListener(_onRepoUpdated);
    }
    super.dispose();
  }

  /// Only listen to the repo while this avatar's thumbnail is not yet cached.
  void _startListeningIfNeeded() {
    final hasThumb =
        widget.contact.thumbnail != null &&
        widget.contact.thumbnail!.isNotEmpty;
    if (!hasThumb && !_repo.hasThumbnail(widget.contact.id) && !_listening) {
      _listening = true;
      _repo.addListener(_onRepoUpdated);
    }
  }

  void _onRepoUpdated() {
    if (!mounted) return;
    // Once thumbnail is available, stop listening and do one final rebuild.
    if (_repo.hasThumbnail(widget.contact.id)) {
      _repo.removeListener(_onRepoUpdated);
      _listening = false;
    }
    setState(() {});
  }

  String _getInitials() {
    final name = widget.contact.displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Use inline thumbnail from contact if available, otherwise lazily load
    final inlineThumbnail = widget.contact.thumbnail;
    final hasInline = inlineThumbnail != null && inlineThumbnail.isNotEmpty;
    final Uint8List? thumbnail = hasInline
        ? inlineThumbnail
        : _repo.getThumbnail(widget.contact.id);
    final hasThumbnail = thumbnail != null && thumbnail.isNotEmpty;

    final primaryColor = ContactAvatar.colorFromName(
      widget.contact.displayName,
    );
    final secondaryColor = ContactAvatar._secondaryColorFromName(
      widget.contact.displayName,
    );
    final effectiveFontSize = widget.fontSize ?? widget.radius * 0.75;

    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.showBorder
            ? Border.all(color: MyContactsColors.white.withValues(alpha: 0.4), width: 3)
            : null,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: widget.showBorder ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: hasThumbnail
              ? Image.memory(
                  thumbnail,
                  key: ValueKey('thumb-${widget.contact.id}'),
                  fit: BoxFit.cover,
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  // Avoid decoding huge images — limit to what we need
                  cacheWidth: (widget.radius * 2 * 2).toInt(), // 2x for retina
                )
              : Container(
                  key: ValueKey('initials-${widget.contact.id}'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, secondaryColor],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(),
                      style: TextStyle(
                        color: MyContactsColors.white,
                        fontSize: effectiveFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
