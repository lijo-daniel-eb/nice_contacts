import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:my_contacts/screens/fake_call_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FakeCallSchedulerService {
  static final FakeCallSchedulerService _instance =
      FakeCallSchedulerService._internal();
  factory FakeCallSchedulerService() => _instance;
  FakeCallSchedulerService._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _scheduledFakeCallsKey = 'scheduled_fake_calls';
  static const String _channelId = 'scheduled_fake_calls';
  static const String _channelName = 'Scheduled Fake Calls';
  static const String _channelDescription =
      'Notifications for scheduled fake calls';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _pendingPayload;
  Timer? _dueWatcher;
  bool _isTriggerInProgress = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _pendingPayload = launchDetails?.notificationResponse?.payload;
    }

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
    startDueScheduleWatcher();
  }

  void startDueScheduleWatcher() {
    _dueWatcher ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _processDueSchedules();
    });
  }

  Future<void> requestPermissions() async {
    final android =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await android?.requestNotificationsPermission();

    final ios =
        _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos =
        _notifications
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<int> scheduleFakeCall({
    required String contactId,
    required String contactName,
    required String phoneNumber,
    required DateTime when,
  }) async {
    await init();
    await requestPermissions();

    final now = DateTime.now();
    final target = when.isBefore(now.add(const Duration(seconds: 1)))
        ? now.add(const Duration(seconds: 2))
        : when;

    final id = _buildScheduleId(contactId, phoneNumber, target);

    final payload = jsonEncode({
      'type': 'scheduled_fake_call',
      'scheduleId': id,
      'contactId': contactId,
      'phoneNumber': phoneNumber,
    });

    await _notifications.zonedSchedule(
      id,
      contactName,
      'Incoming fake call',
      tz.TZDateTime.from(target, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    await _upsertScheduledCall(
      ScheduledFakeCall(
        id: id,
        contactId: contactId,
        contactName: contactName,
        phoneNumber: phoneNumber,
        scheduledAt: target,
      ),
    );

    startDueScheduleWatcher();

    return id;
  }

  Future<List<ScheduledFakeCall>> getScheduledCallsFor(
    String contactId,
    String phoneNumber,
  ) async {
    final all = await _getScheduledCalls();
    final now = DateTime.now();
    final filtered = all
        .where(
          (e) =>
              e.contactId == contactId &&
              e.phoneNumber == phoneNumber &&
              e.scheduledAt.isAfter(now.subtract(const Duration(seconds: 1))),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return filtered;
  }

  Future<ScheduledFakeCall?> getNextScheduledCallFor(
    String contactId,
    String phoneNumber,
  ) async {
    final calls = await getScheduledCallsFor(contactId, phoneNumber);
    if (calls.isEmpty) return null;
    return calls.first;
  }

  Future<void> cancelScheduledFakeCall(int scheduleId) async {
    await _notifications.cancel(scheduleId);
    final all = await _getScheduledCalls();
    all.removeWhere((e) => e.id == scheduleId);
    await _saveScheduledCalls(all);
  }

  Future<void> processPendingNotificationTap() async {
    if (_pendingPayload == null || _pendingPayload!.isEmpty) return;
    final payload = _pendingPayload!;
    _pendingPayload = null;
    await _handlePayload(payload);
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    await _handlePayload(payload);
  }

  Future<void> _handlePayload(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] != 'scheduled_fake_call') return;

      final contactId = data['contactId'] as String?;
      final phoneNumber = data['phoneNumber'] as String?;
      final scheduleId = (data['scheduleId'] as num?)?.toInt();
      if (contactId == null || phoneNumber == null) return;

      if (scheduleId != null) {
        await cancelScheduledFakeCall(scheduleId);
      }

      await _openFakeCall(contactId: contactId, phoneNumber: phoneNumber);
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  Future<void> _processDueSchedules() async {
    if (_isTriggerInProgress) return;
    if (!_initialized) return;
    if (_pendingPayload != null && _pendingPayload!.isNotEmpty) return;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != AppLifecycleState.resumed) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final all = await _getScheduledCalls();
    if (all.isEmpty) return;

    final now = DateTime.now();
    final due = all
        .where((e) => !e.scheduledAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (due.isEmpty) return;

    final firstDue = due.first;

    _isTriggerInProgress = true;
    try {
      await cancelScheduledFakeCall(firstDue.id);
      await _openFakeCall(
        contactId: firstDue.contactId,
        phoneNumber: firstDue.phoneNumber,
      );
    } finally {
      _isTriggerInProgress = false;
    }
  }

  Future<void> _openFakeCall({
    required String contactId,
    required String phoneNumber,
  }) async {
    await ContactsRepository().ensureLoaded();
    final contact = _findContactById(contactId);
    if (contact == null) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _pendingPayload = jsonEncode({
        'type': 'scheduled_fake_call',
        'contactId': contactId,
        'phoneNumber': phoneNumber,
      });
      return;
    }

    await Navigator.of(ctx).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => FakeCallScreen(
          contact: contact,
          phoneNumber: phoneNumber,
          autoAttend: PreferencesService().getAutoAttendFakeCalls(),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Contact? _findContactById(String contactId) {
    for (final contact in ContactsRepository().contacts) {
      if (contact.id == contactId) return contact;
    }
    return null;
  }

  Future<List<ScheduledFakeCall>> _getScheduledCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scheduledFakeCallsKey) ?? [];
    return raw
        .map((e) {
          try {
            return ScheduledFakeCall.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<ScheduledFakeCall>()
        .toList();
  }

  Future<void> _saveScheduledCalls(List<ScheduledFakeCall> calls) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = calls.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_scheduledFakeCallsKey, encoded);
  }

  Future<void> _upsertScheduledCall(ScheduledFakeCall call) async {
    final all = await _getScheduledCalls();
    all.removeWhere((e) => e.id == call.id);
    all.add(call);
    await _saveScheduledCalls(all);
  }

  int _buildScheduleId(String contactId, String phoneNumber, DateTime when) {
    final source = '$contactId|$phoneNumber|${when.millisecondsSinceEpoch}';
    return _stablePositiveHash(source);
  }

  int _stablePositiveHash(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }
}

class ScheduledFakeCall {
  final int id;
  final String contactId;
  final String contactName;
  final String phoneNumber;
  final DateTime scheduledAt;

  const ScheduledFakeCall({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.phoneNumber,
    required this.scheduledAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactId': contactId,
    'contactName': contactName,
    'phoneNumber': phoneNumber,
    'scheduledAt': scheduledAt.toIso8601String(),
  };

  factory ScheduledFakeCall.fromJson(Map<String, dynamic> json) {
    return ScheduledFakeCall(
      id: json['id'] as int,
      contactId: json['contactId'] as String,
      contactName: json['contactName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
    );
  }
}
