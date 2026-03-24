import 'dart:io';

import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

export 'package:call_log/call_log.dart' show CallLogEntry, CallType;

/// Service for reading the device's native call log on Android.
class CallLogService {
  static final CallLogService _instance = CallLogService._internal();
  factory CallLogService() => _instance;
  CallLogService._internal();

  static bool get isSupported => Platform.isAndroid;

  /// Returns current call log permission status.
  Future<PermissionStatus> get permissionStatus async {
    if (!isSupported) return PermissionStatus.denied;
    return await Permission.phone.status;
  }

  /// Requests call log permission. Returns true if now granted.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  /// Fetches up to [limit] most recent call log entries (newest first).
  /// Returns empty list if unsupported, permission denied, or on error.
  Future<List<CallLogEntry>> getEntries({int limit = 200}) async {
    if (!isSupported) return [];
    final status = await Permission.phone.status;
    if (!status.isGranted) return [];
    try {
      final entries = await CallLog.get();
      return entries.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Normalises a phone number to its last 10 digits for matching.
  static String normalizeNumber(String? number) {
    if (number == null || number.isEmpty) return '';
    final digits = number.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }
}
