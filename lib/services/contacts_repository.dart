import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Shared repository that loads contacts ONCE and provides cached data
/// to all screens — eliminating redundant FlutterContacts.getContacts() calls.
class ContactsRepository extends ChangeNotifier {
  static final ContactsRepository _instance = ContactsRepository._internal();
  factory ContactsRepository() => _instance;
  ContactsRepository._internal();

  List<Contact> _contacts = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _permissionDenied = false;
  DateTime? _lastRefresh;

  /// All contacts (with properties, may include thumbnails).
  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get permissionDenied => _permissionDenied;

  /// Load contacts if not yet loaded.
  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;
    await refresh();
  }

  /// Force a full reload from the OS contacts store.
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        _permissionDenied = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Phase 1: Fast load — properties only (no thumbnails)
      final fast = await FlutterContacts.getContacts(withProperties: true);
      _contacts = fast;
      _hasLoaded = true;
      _isLoading = false;
      _permissionDenied = false;
      _lastRefresh = DateTime.now();
      notifyListeners();

      // Phase 2: Background load — add thumbnails
      final full = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: true,
      );
      _contacts = full;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Soft refresh if stale (older than [maxAge]).
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 2),
  }) async {
    if (_lastRefresh == null ||
        DateTime.now().difference(_lastRefresh!) > maxAge) {
      await refresh();
    }
  }
}
