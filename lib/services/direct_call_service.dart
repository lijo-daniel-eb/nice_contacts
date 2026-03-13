import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Places a phone call directly (ACTION_CALL) on Android.
/// Falls back to the dialer (ACTION_DIAL) on other platforms.
class DirectCallService {
  static const _channel = MethodChannel(
    'com.lijojolly.my_contacts/direct_call',
  );

  static Future<void> call(String number) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('directCall', {'number': number});
      } on PlatformException {
        // Fallback to dialer if the channel fails
        final uri = Uri(scheme: 'tel', path: number);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } else {
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}
