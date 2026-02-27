import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Shared repository that loads contacts ONCE and provides cached data
/// to all screens — eliminating redundant FlutterContacts.getContacts() calls.
///
/// Thumbnails are loaded lazily per-contact rather than bulk-loading all 700+
/// at once, which dramatically improves startup time.
class ContactsRepository extends ChangeNotifier {
  static final ContactsRepository _instance = ContactsRepository._internal();
  factory ContactsRepository() => _instance;
  ContactsRepository._internal();

  List<Contact> _contacts = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _permissionDenied = false;
  DateTime? _lastRefresh;

  /// Thumbnail cache: contactId → thumbnail bytes (null = not yet loaded).
  final Map<String, Uint8List?> _thumbnailCache = {};

  /// Track in-flight thumbnail requests to avoid duplicate fetches.
  final Set<String> _thumbnailLoading = {};

  /// All contacts (with properties — thumbnails loaded lazily).
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
      if (!await FlutterContacts.requestPermission()) {
        _permissionDenied = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fast load — properties only (no thumbnails).
      // With 700+ contacts this returns in ~200ms instead of several seconds.
      final fast = await FlutterContacts.getContacts(withProperties: true);
      _contacts = fast;
      _hasLoaded = true;
      _isLoading = false;
      _permissionDenied = false;
      _lastRefresh = DateTime.now();
      _thumbnailCache.clear();
      _thumbnailLoading.clear();
      notifyListeners();

      // Prefetch visible thumbnails in small batches (first ~30 contacts)
      // so the initial screen looks populated quickly.
      _prefetchThumbnails(fast.take(30).toList());
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a cached thumbnail for a contact. Returns null if not yet loaded.
  /// Automatically triggers a lazy fetch if not cached.
  Uint8List? getThumbnail(String contactId) {
    if (_thumbnailCache.containsKey(contactId)) {
      return _thumbnailCache[contactId];
    }
    // Kick off a lazy load
    _loadThumbnail(contactId);
    return null;
  }

  /// Load a single contact's thumbnail in the background.
  Future<void> _loadThumbnail(String contactId) async {
    if (_thumbnailCache.containsKey(contactId)) return;
    if (_thumbnailLoading.contains(contactId)) return;
    _thumbnailLoading.add(contactId);

    try {
      final full = await FlutterContacts.getContact(
        contactId,
        withThumbnail: true,
      );
      _thumbnailCache[contactId] = full?.thumbnail;
      _thumbnailLoading.remove(contactId);
      notifyListeners();
    } catch (_) {
      _thumbnailLoading.remove(contactId);
      _thumbnailCache[contactId] = null; // mark as tried
    }
  }

  /// Prefetch thumbnails for a batch of contacts (e.g. visible ones).
  Future<void> _prefetchThumbnails(List<Contact> batch) async {
    // Load in small parallel chunks to avoid overwhelming the contacts API
    const chunkSize = 8;
    for (int i = 0; i < batch.length; i += chunkSize) {
      final chunk = batch.skip(i).take(chunkSize);
      await Future.wait(chunk.map((c) => _loadThumbnail(c.id)));
    }
  }

  /// Prefetch thumbnails for contacts that are about to scroll into view.
  void prefetchForVisible(List<Contact> visibleContacts) {
    for (final c in visibleContacts) {
      if (!_thumbnailCache.containsKey(c.id) &&
          !_thumbnailLoading.contains(c.id)) {
        _loadThumbnail(c.id);
      }
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
