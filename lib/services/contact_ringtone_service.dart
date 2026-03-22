import 'package:flutter/services.dart';

/// Applies a custom ringtone to an Android contact at the system level.
///
/// The file is registered in Android's MediaStore so the telephony service
/// can find and play it when the contact calls. On non-Android platforms
/// every call is silently ignored (best-effort).
class ContactRingtoneService {
  ContactRingtoneService._();

  static const _channel = MethodChannel('com.lijojolly.my_contacts/ringtone');

  /// Registers [filePath] in MediaStore and assigns it as the custom ringtone
  /// for the contact identified by [contactId].
  ///
  /// Throws nothing – failures are swallowed so the app keeps working even
  /// when the system denies access.
  static Future<void> setSystemRingtone({
    required String contactId,
    required String filePath,
  }) async {
    try {
      await _channel.invokeMethod<void>('setContactRingtone', {
        'contactId': contactId,
        'filePath': filePath,
      });
    } on PlatformException {
      // Best-effort; silently skip on permission denial or unsupported platform.
    }
  }

  /// Removes the custom ringtone assignment from the system contact, restoring
  /// the device's default ringtone for incoming calls from this contact.
  static Future<void> clearSystemRingtone({required String contactId}) async {
    try {
      await _channel.invokeMethod<void>('clearContactRingtone', {
        'contactId': contactId,
      });
    } on PlatformException {
      // Best-effort.
    }
  }
}
