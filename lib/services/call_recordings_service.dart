import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CallRecordingItem {
  final String path;
  final String fileName;
  final DateTime modifiedAt;
  final int sizeBytes;

  const CallRecordingItem({
    required this.path,
    required this.fileName,
    required this.modifiedAt,
    required this.sizeBytes,
  });
}

class CallRecordingsService {
  static final CallRecordingsService _instance =
      CallRecordingsService._internal();
  factory CallRecordingsService() => _instance;
  CallRecordingsService._internal();

  final _prefsService = PreferencesService();

  static const List<String> _candidateDirs = [
    '/storage/emulated/0/Call',
    '/storage/emulated/0/CallRecordings',
    '/storage/emulated/0/Recordings/Call',
    '/storage/emulated/0/Recordings/PhoneRecord',
    '/storage/emulated/0/MIUI/sound_recorder/call_rec',
    '/storage/emulated/0/Sounds/CallRecordings',
  ];

  static const Set<String> _audioExt = {
    '.m4a',
    '.mp3',
    '.amr',
    '.wav',
    '.aac',
    '.3gp',
    '.ogg',
  };

  DateTime? _lastScanAt;
  List<CallRecordingItem> _cached = const [];

  Future<List<CallRecordingItem>> getRecordingsForContact(Contact contact) async {
    if (kIsWeb || !Platform.isAndroid) return const [];

    final granted = await _ensurePermission();
    if (!granted) return const [];

    await _refreshCacheIfNeeded();

    final nameTokens = _contactNameTokens(contact);
    final phoneKeys = _contactPhoneKeys(contact);
    if (phoneKeys.isEmpty && nameTokens.isEmpty) return const [];

    final matched = <_MatchedRecording>[];
    for (final item in _cached) {
      final nameMatched = _matchesContactName(item.fileName, nameTokens);

      if (nameMatched) {
        matched.add(_MatchedRecording(item: item, nameMatched: true));
        continue;
      }

      final fileDigits = _digitsOnly(item.fileName);
      if (fileDigits.length < 8) continue;
      final numberMatched = phoneKeys.any(fileDigits.contains);
      if (numberMatched) {
        matched.add(_MatchedRecording(item: item, nameMatched: false));
      }
    }

    matched.sort((a, b) {
      if (a.nameMatched != b.nameMatched) {
        return a.nameMatched ? -1 : 1;
      }
      return b.item.modifiedAt.compareTo(a.item.modifiedAt);
    });

    return matched.map((m) => m.item).toList();
  }

  Future<void> _refreshCacheIfNeeded() async {
    final now = DateTime.now();
    if (_lastScanAt != null && now.difference(_lastScanAt!) < const Duration(minutes: 2)) {
      return;
    }

    final found = <CallRecordingItem>[];
    for (final dirPath in _allCandidateDirs()) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final lower = entity.path.toLowerCase();
          if (!_audioExt.any(lower.endsWith)) continue;

          try {
            final stat = await entity.stat();
            if (stat.size <= 0) continue;
            found.add(
              CallRecordingItem(
                path: entity.path,
                fileName: entity.uri.pathSegments.isNotEmpty
                    ? entity.uri.pathSegments.last
                    : entity.path.split('/').last,
                modifiedAt: stat.modified,
                sizeBytes: stat.size,
              ),
            );
          } catch (_) {
            // Ignore unreadable files.
          }
        }
      } catch (_) {
        // Ignore restricted directories.
      }
    }

    _cached = found;
    _lastScanAt = now;
  }

  Future<bool> _ensurePermission() async {
    final audioStatus = await Permission.audio.request();

    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  List<String> _allCandidateDirs() {
    final customPath = _prefsService.getCallRecordingsPath().trim();
    if (customPath.isEmpty) return _candidateDirs;
    return [customPath, ..._candidateDirs.where((p) => p != customPath)];
  }

  Set<String> _contactPhoneKeys(Contact contact) {
    final keys = <String>{};
    for (final phone in contact.phones) {
      final digits = _digitsOnly(phone.number);
      if (digits.length >= 8) {
        keys.add(digits.substring(digits.length - 8));
      }
    }
    return keys;
  }

  List<String> _contactNameTokens(Contact contact) {
    final keys = <String>[];
    final displayName = contact.displayName.trim().toLowerCase();
    if (displayName.isNotEmpty) {
      for (final part in displayName.split(RegExp(r'\s+'))) {
        final token = part.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (token.length >= 2) keys.add(token);
      }
    }
    return keys;
  }

  bool _matchesContactName(String fileName, List<String> nameTokens) {
    if (nameTokens.isEmpty) return false;

    final lower = fileName.toLowerCase();
    final fileTokens = lower
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toSet();

    // For names with multiple words (e.g. "Rinsy Papa"), require all words.
    if (nameTokens.length > 1) {
      return nameTokens.every(fileTokens.contains);
    }

    // For single-word names, accept exact token match.
    return fileTokens.contains(nameTokens.first);
  }

  String _digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');
}

class _MatchedRecording {
  final CallRecordingItem item;
  final bool nameMatched;

  const _MatchedRecording({required this.item, required this.nameMatched});
}
