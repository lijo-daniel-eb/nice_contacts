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
  static const String _accentColorKey = 'accent_color';

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

  int getAccentColor() => _prefs.getInt(_accentColorKey) ?? 0xFF1B98E0;
  Future<void> setAccentColor(int color) =>
      _prefs.setInt(_accentColorKey, color);
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
