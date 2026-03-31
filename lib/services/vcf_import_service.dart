import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';

/// Result summary returned after a VCF import run.
class VcfImportResult {
  /// Number of contacts successfully saved to the device.
  final int imported;

  /// Number of entries skipped (e.g. empty / unparseable vCards).
  final int skipped;

  /// Any non-fatal error messages collected during import.
  final List<String> errors;

  const VcfImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
}

/// Parses a VCF file and inserts each contact into the device contacts store.
///
/// Progress is reported via [onProgress] with (done, total) counts.
class VcfImportService {
  /// Import all contacts from [filePath].
  ///
  /// [onProgress] is called after each contact is processed so callers can
  /// update a progress indicator. It receives (done, total).
  Future<VcfImportResult> importFromFile(
    String filePath, {
    void Function(int done, int total)? onProgress,
  }) async {
    final raw = await File(filePath).readAsString();

    // Split the file into individual vCard blocks.
    final blocks = _splitVCards(raw);
    final total = blocks.length;

    int imported = 0;
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i].trim();
      if (block.isEmpty) {
        skipped++;
        onProgress?.call(i + 1, total);
        continue;
      }

      try {
        final contact = Contact.fromVCard(block);

        // Skip truly empty entries (no name and no phones).
        if (contact.displayName.isEmpty && contact.phones.isEmpty) {
          skipped++;
          onProgress?.call(i + 1, total);
          continue;
        }

        await FlutterContacts.insertContact(contact);
        imported++;
      } catch (e) {
        skipped++;
        errors.add('Entry ${i + 1}: $e');
      }

      onProgress?.call(i + 1, total);
    }

    return VcfImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  /// Split a multi-vCard string into individual vCard blocks.
  List<String> _splitVCards(String content) {
    // Normalise line endings.
    final normalised = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final blocks = <String>[];
    final buffer = StringBuffer();
    bool inside = false;

    for (final line in normalised.split('\n')) {
      final upper = line.trim().toUpperCase();
      if (upper == 'BEGIN:VCARD') {
        inside = true;
        buffer.clear();
      }
      if (inside) {
        buffer.writeln(line);
      }
      if (upper == 'END:VCARD') {
        inside = false;
        blocks.add(buffer.toString());
        buffer.clear();
      }
    }

    return blocks;
  }
}
