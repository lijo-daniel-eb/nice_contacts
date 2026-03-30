import 'dart:convert';
import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';

/// Exports a list of contacts to a VCF (vCard 3.0) file.
class VcfExportService {
  /// Generates a VCF file from [contacts] and writes it to the app temp
  /// directory. Returns the file path so the caller can share/save it.
  Future<String> exportContacts(List<Contact> contacts) async {
    final buffer = StringBuffer();
    for (final contact in contacts) {
      _appendContact(buffer, contact);
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/contacts_export.vcf');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  void _appendContact(StringBuffer buf, Contact c) {
    buf.writeln('BEGIN:VCARD');
    buf.writeln('VERSION:3.0');

    // Full name (FN is required in VCF 3.0)
    final fn = c.displayName;
    if (fn.isNotEmpty) {
      buf.writeln('FN:${_esc(fn)}');
    }

    // Structured name: LastName;FirstName;MiddleName;Prefix;Suffix
    final n = c.name;
    buf.writeln(
      'N:${_esc(n.last)};${_esc(n.first)};${_esc(n.middle)};${_esc(n.prefix)};${_esc(n.suffix)}',
    );

    // Phone numbers
    for (final phone in c.phones) {
      final type = _phoneType(phone.label, phone.customLabel);
      buf.writeln('TEL;TYPE=$type:${phone.number}');
    }

    // Email addresses
    for (final email in c.emails) {
      final type = _emailType(email.label, email.customLabel);
      buf.writeln('EMAIL;TYPE=$type:${email.address}');
    }

    // Addresses: PO Box;Extended;Street;City;State;PostalCode;Country
    for (final addr in c.addresses) {
      final type = _addrType(addr.label, addr.customLabel);
      buf.writeln(
        'ADR;TYPE=$type:${_esc(addr.pobox)};${_esc(addr.neighborhood)};${_esc(addr.street)};${_esc(addr.city)};${_esc(addr.state)};${_esc(addr.postalCode)};${_esc(addr.country)}',
      );
    }

    // Organizations
    for (final org in c.organizations) {
      if (org.company.isNotEmpty) {
        final orgValue = org.department.isNotEmpty
            ? '${_esc(org.company)};${_esc(org.department)}'
            : _esc(org.company);
        buf.writeln('ORG:$orgValue');
      }
      if (org.title.isNotEmpty) {
        buf.writeln('TITLE:${_esc(org.title)}');
      }
    }

    // Notes
    for (final note in c.notes) {
      if (note.note.isNotEmpty) {
        buf.writeln('NOTE:${_escNote(note.note)}');
      }
    }

    // Photo (prefer full-size, fall back to thumbnail)
    final photoBytes = c.photo ?? c.thumbnail;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      final b64 = base64Encode(photoBytes);
      // vCard 3.0: fold long base64 lines at 75 chars after the property name
      buf.writeln('PHOTO;ENCODING=b;TYPE=JPEG:$b64');
    }

    buf.writeln('END:VCARD');
  }

  /// Escape special characters for VCF text values.
  String _esc(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\r', '')
      .replaceAll('\n', '\\n');

  /// Escape for multi-line NOTE values (comma-escaping not needed per spec).
  String _escNote(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll('\r', '')
      .replaceAll('\n', '\\n');

  String _phoneType(PhoneLabel label, String customLabel) {
    return switch (label) {
      PhoneLabel.mobile => 'CELL',
      PhoneLabel.home => 'HOME',
      PhoneLabel.work => 'WORK',
      PhoneLabel.faxWork => 'FAX,WORK',
      PhoneLabel.faxHome => 'FAX,HOME',
      PhoneLabel.faxOther => 'FAX',
      PhoneLabel.pager || PhoneLabel.workPager => 'PAGER',
      PhoneLabel.car => 'CAR',
      PhoneLabel.main || PhoneLabel.companyMain => 'PREF',
      PhoneLabel.custom =>
        customLabel.isNotEmpty ? customLabel.toUpperCase() : 'VOICE',
      _ => 'VOICE',
    };
  }

  String _emailType(EmailLabel label, String customLabel) {
    return switch (label) {
      EmailLabel.home => 'HOME',
      EmailLabel.work => 'WORK',
      EmailLabel.custom =>
        customLabel.isNotEmpty ? customLabel.toUpperCase() : 'INTERNET',
      _ => 'INTERNET',
    };
  }

  String _addrType(AddressLabel label, String customLabel) {
    return switch (label) {
      AddressLabel.home => 'HOME',
      AddressLabel.work => 'WORK',
      AddressLabel.custom =>
        customLabel.isNotEmpty ? customLabel.toUpperCase() : 'POSTAL',
      _ => 'POSTAL',
    };
  }
}
