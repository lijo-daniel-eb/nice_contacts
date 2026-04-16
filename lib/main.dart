import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nice_contacts/screens/home_screen.dart';
import 'package:nice_contacts/services/contacts_repository.dart';
import 'package:nice_contacts/services/fake_call_scheduler_service.dart';
import 'package:nice_contacts/services/preferences_service.dart';
import 'package:nice_contacts/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService().init();
  await MobileAds.instance.initialize();
  // Start loading contacts early — all screens share this cache
  ContactsRepository().ensureLoaded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: FakeCallSchedulerService.navigatorKey,
      title: 'NICE Contacts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _getThemeMode(),
      home: const HomeScreen(),
    );
  }

  ThemeMode _getThemeMode() {
    final mode = PreferencesService().getThemeMode();
    return switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
