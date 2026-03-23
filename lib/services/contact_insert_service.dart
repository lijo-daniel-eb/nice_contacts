import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactInsertService {
  static const _channel = MethodChannel(
    'com.lijojolly.my_contacts/contact_ops',
  );

  static Future<Contact> insertContactSafely(Contact contact) async {
    if (!Platform.isAndroid) {
      return FlutterContacts.insertContact(contact);
    }

    final json = await _channel.invokeMapMethod<String, dynamic>(
      'insertContactSafely',
      {'contact': contact.toJson()},
    );

    if (json == null) {
      throw PlatformException(
        code: 'FAILED',
        message: 'Native contact insert returned no contact',
      );
    }

    return Contact.fromJson(Map<String, dynamic>.from(json));
  }
}