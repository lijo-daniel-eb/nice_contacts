import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for managing app preferences, favourites, and recent contacts.
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _favouritesKey = 'favourite_contact_ids';
  static const String _recentsKey = 'recent_contacts';
  static const String _themeKey = 'theme_mode';
  static const String _sortOrderKey = 'sort_order';
  static const String _defaultTabKey = 'default_tab';
  static const String _showPhoneInListKey = 'show_phone_in_list';
  static const String _autoAttendFakeCallsKey = 'auto_attend_fake_calls';
  static const String _callRecordingsPathKey = 'call_recordings_path';
  static const String _availableContactGroupsKey = 'available_contact_groups';
  static const String _contactGroupsMapKey = 'contact_groups_map';
  static const String _availableOrganizationTagsKey = 'available_organization_tags';

  static const List<String> _defaultContactGroups = [
    'Family',
    'Friends',
    'Work',
    'VIP',
    'Emergency',
  ];

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Favourites ---

  Set<String> getFavourites() {
    return _prefs.getStringList(_favouritesKey)?.toSet() ?? {};
  }

  bool isFavourite(String contactId) {
    return getFavourites().contains(contactId);
  }

  Future<void> toggleFavourite(String contactId) async {
    final favs = getFavourites();
    if (favs.contains(contactId)) {
      favs.remove(contactId);
    } else {
      favs.add(contactId);
    }
    await _prefs.setStringList(_favouritesKey, favs.toList());
  }

  Future<void> addFavourite(String contactId) async {
    final favs = getFavourites();
    favs.add(contactId);
    await _prefs.setStringList(_favouritesKey, favs.toList());
  }

  Future<void> removeFavourite(String contactId) async {
    final favs = getFavourites();
    favs.remove(contactId);
    await _prefs.setStringList(_favouritesKey, favs.toList());
  }

  // --- Recent Contacts ---

  List<RecentContact> getRecents() {
    final data = _prefs.getStringList(_recentsKey) ?? [];
    return data.map((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return RecentContact.fromJson(map);
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addRecent(
    String contactId,
    String contactName,
    String action,
  ) async {
    final recents = _prefs.getStringList(_recentsKey) ?? [];
    final recent = RecentContact(
      contactId: contactId,
      contactName: contactName,
      action: action,
      timestamp: DateTime.now(),
    );
    recents.insert(0, jsonEncode(recent.toJson()));

    // Keep only last 100 entries
    if (recents.length > 100) {
      recents.removeRange(100, recents.length);
    }
    await _prefs.setStringList(_recentsKey, recents);
  }

  Future<void> clearRecents() async {
    await _prefs.setStringList(_recentsKey, []);
  }

  // --- Contact Groups ---

  List<String> getAvailableContactGroups() {
    final stored = _prefs.getStringList(_availableContactGroupsKey) ?? [];
    final merged = <String>[];

    for (final g in [..._defaultContactGroups, ...stored]) {
      final trimmed = g.trim();
      if (trimmed.isEmpty) continue;
      final exists = merged.any(
        (m) => m.toLowerCase() == trimmed.toLowerCase(),
      );
      if (!exists) merged.add(trimmed);
    }

    return merged;
  }

  Future<void> addAvailableContactGroup(String groupName) async {
    final trimmed = groupName.trim();
    if (trimmed.isEmpty) return;

    final stored = _prefs.getStringList(_availableContactGroupsKey) ?? [];
    final existsInDefaults = _defaultContactGroups.any(
      (g) => g.toLowerCase() == trimmed.toLowerCase(),
    );
    final existsInStored = stored.any(
      (g) => g.toLowerCase() == trimmed.toLowerCase(),
    );

    if (!existsInDefaults && !existsInStored) {
      stored.add(trimmed);
      await _prefs.setStringList(_availableContactGroupsKey, stored);
    }
  }

  List<String> getContactGroups(String contactId) {
    final map = _getContactGroupsMap();
    return map[contactId] ?? const [];
  }

  Future<void> setContactGroups(String contactId, List<String> groups) async {
    final map = _getContactGroupsMap();
    final cleaned = <String>[];

    for (final g in groups) {
      final trimmed = g.trim();
      if (trimmed.isEmpty) continue;
      final exists = cleaned.any(
        (c) => c.toLowerCase() == trimmed.toLowerCase(),
      );
      if (!exists) cleaned.add(trimmed);
    }

    if (cleaned.isEmpty) {
      map.remove(contactId);
    } else {
      map[contactId] = cleaned;
    }

    await _prefs.setString(_contactGroupsMapKey, jsonEncode(map));
  }

  Map<String, List<String>> _getContactGroupsMap() {
    final raw = _prefs.getString(_contactGroupsMapKey);
    if (raw == null || raw.trim().isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is List) {
          result[entry.key] = value.map((e) => e.toString()).toList();
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  // --- Organization Tags ---

  List<String> getAvailableOrganizationTags() {
    final stored = _prefs.getStringList(_availableOrganizationTagsKey) ?? [];
    final cleaned = <String>[];

    for (final tag in stored) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      final exists = cleaned.any((c) => c.toLowerCase() == trimmed.toLowerCase());
      if (!exists) cleaned.add(trimmed);
    }

    return cleaned;
  }

  Future<void> addAvailableOrganizationTag(String tagName) async {
    final trimmed = tagName.trim();
    if (trimmed.isEmpty) return;

    final stored = _prefs.getStringList(_availableOrganizationTagsKey) ?? [];
    final exists = stored.any((t) => t.toLowerCase() == trimmed.toLowerCase());
    if (!exists) {
      stored.add(trimmed);
      await _prefs.setStringList(_availableOrganizationTagsKey, stored);
    }
  }

  /// Get contacts sorted by frequency (most contacted first)
  Map<String, int> getFrequentlyContacted() {
    final recents = getRecents();
    final Map<String, int> frequency = {};
    for (final r in recents) {
      frequency[r.contactId] = (frequency[r.contactId] ?? 0) + 1;
    }
    return Map.fromEntries(
      frequency.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  // --- Settings ---

  String getThemeMode() => _prefs.getString(_themeKey) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(_themeKey, mode);

  String getSortOrder() => _prefs.getString(_sortOrderKey) ?? 'firstName';
  Future<void> setSortOrder(String order) =>
      _prefs.setString(_sortOrderKey, order);

  int getDefaultTab() => _prefs.getInt(_defaultTabKey) ?? 0;
  Future<void> setDefaultTab(int tab) => _prefs.setInt(_defaultTabKey, tab);

  bool getShowPhoneInList() => _prefs.getBool(_showPhoneInListKey) ?? true;
  Future<void> setShowPhoneInList(bool show) =>
      _prefs.setBool(_showPhoneInListKey, show);

  bool getAutoAttendFakeCalls() =>
      _prefs.getBool(_autoAttendFakeCallsKey) ?? true;
  Future<void> setAutoAttendFakeCalls(bool enabled) =>
      _prefs.setBool(_autoAttendFakeCallsKey, enabled);

  String getCallRecordingsPath() => _prefs.getString(_callRecordingsPathKey) ?? '';
  Future<void> setCallRecordingsPath(String path) =>
      _prefs.setString(_callRecordingsPathKey, path);
  Future<void> clearCallRecordingsPath() =>
      _prefs.remove(_callRecordingsPathKey);
}

class RecentContact {
  final String contactId;
  final String contactName;
  final String action; // 'call', 'message', 'email', 'whatsapp'
  final DateTime timestamp;

  RecentContact({
    required this.contactId,
    required this.contactName,
    required this.action,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'contactId': contactId,
    'contactName': contactName,
    'action': action,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RecentContact.fromJson(Map<String, dynamic> json) => RecentContact(
    contactId: json['contactId'] as String,
    contactName: json['contactName'] as String,
    action: json['action'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
