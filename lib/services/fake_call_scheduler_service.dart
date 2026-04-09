import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:nice_contacts/screens/fake_call_screen.dart';
import 'package:nice_contacts/services/contacts_repository.dart';
import 'package:nice_contacts/services/preferences_service.dart';

class FakeCallSchedulerService {
  static final FakeCallSchedulerService _instance =
      FakeCallSchedulerService._internal();
  factory FakeCallSchedulerService() => _instance;
  FakeCallSchedulerService._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  int _nextId = 1;
  final Map<int, Timer> _timers = {};
  final Map<int, ScheduledFakeCall> _scheduled = {};
  bool _isTriggerInProgress = false;

  Future<int> scheduleFakeCall({
    required String contactId,
    required String contactName,
    required String phoneNumber,
    required DateTime when,
  }) async {
    final now = DateTime.now();
    final target = when.isBefore(now.add(const Duration(seconds: 2)))
        ? now.add(const Duration(seconds: 2))
        : when;

    final id = _nextId++;
    final call = ScheduledFakeCall(
      id: id,
      contactId: contactId,
      contactName: contactName,
      phoneNumber: phoneNumber,
      scheduledAt: target,
    );

    _scheduled[id] = call;
    _scheduleTimer(call);

    return id;
  }

  Future<List<ScheduledFakeCall>> getScheduledCallsFor(
    String contactId,
    String phoneNumber,
  ) async {
    final now = DateTime.now();
    return _scheduled.values
        .where(
          (e) =>
              e.contactId == contactId &&
              e.phoneNumber == phoneNumber &&
              e.scheduledAt.isAfter(now.subtract(const Duration(seconds: 1))),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Future<ScheduledFakeCall?> getNextScheduledCallFor(
    String contactId,
    String phoneNumber,
  ) async {
    final calls = await getScheduledCallsFor(contactId, phoneNumber);
    return calls.isEmpty ? null : calls.first;
  }

  Future<void> cancelScheduledFakeCall(int id) async {
    _timers.remove(id)?.cancel();
    _scheduled.remove(id);
  }

  void startDueScheduleWatcher() {
    // Intentionally no-op for in-app timer mode.
  }

  Future<void> processPendingNotificationTap() async {
    // Intentionally no-op for in-app timer mode.
  }

  void _scheduleTimer(ScheduledFakeCall call) {
    _timers.remove(call.id)?.cancel();
    final delay = call.scheduledAt.difference(DateTime.now());
    final safeDelay = delay.isNegative ? Duration.zero : delay;

    _timers[call.id] = Timer(safeDelay, () async {
      _timers.remove(call.id);
      _scheduled.remove(call.id);
      await _openFakeCallScreen(
        contactId: call.contactId,
        phoneNumber: call.phoneNumber,
      );
    });
  }

  Future<void> _openFakeCallScreen({
    required String contactId,
    required String phoneNumber,
  }) async {
    if (_isTriggerInProgress) return;
    _isTriggerInProgress = true;

    try {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        return;
      }

      await ContactsRepository().ensureLoaded();
      final contact = _findContactById(contactId);
      if (contact == null) return;

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      await navigator.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              FakeCallScreen(
                contact: contact,
                phoneNumber: phoneNumber,
                autoAttend: PreferencesService().getAutoAttendFakeCalls(),
              ),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } finally {
      _isTriggerInProgress = false;
    }
  }

  Contact? _findContactById(String contactId) {
    for (final c in ContactsRepository().contacts) {
      if (c.id == contactId) return c;
    }
    return null;
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
}
