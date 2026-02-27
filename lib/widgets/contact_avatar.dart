import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// A beautiful contact avatar that shows the contact's photo or initials
/// with a gradient background derived from the contact's name.
class ContactAvatar extends StatelessWidget {
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
  static Color _colorFromName(String name) {
    final colors = [
      const Color(0xFF6C63FF), // Purple
      const Color(0xFFFF6584), // Pink
      const Color(0xFF43E97B), // Green
      const Color(0xFFFFA62E), // Orange
      const Color(0xFF00C9FF), // Cyan
      const Color(0xFFFC5C7D), // Rose
      const Color(0xFF6A82FB), // Blue
      const Color(0xFFE91E63), // Deep Pink
      const Color(0xFF00BCD4), // Teal
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFF9C27B0), // Purple Deep
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }

  static Color _secondaryColorFromName(String name) {
    final colors = [
      const Color(0xFF8B83FF),
      const Color(0xFFFF8BA7),
      const Color(0xFF66F09B),
      const Color(0xFFFFBE5C),
      const Color(0xFF4DD8FF),
      const Color(0xFFFF8DA1),
      const Color(0xFF8DA5FF),
      const Color(0xFFF06292),
      const Color(0xFF26C6DA),
      const Color(0xFFFF8A65),
      const Color(0xFFAED581),
      const Color(0xFFBA68C8),
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }

  String _getInitials() {
    final name = contact.displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail =
        contact.thumbnail != null && contact.thumbnail!.isNotEmpty;
    final primaryColor = _colorFromName(contact.displayName);
    final secondaryColor = _secondaryColorFromName(contact.displayName);
    final effectiveFontSize = fontSize ?? radius * 0.75;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3)
            : null,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: showBorder ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: hasThumbnail
            ? Image.memory(
                contact.thumbnail!,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
              )
            : Container(
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
                      color: Colors.white,
                      fontSize: effectiveFontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
