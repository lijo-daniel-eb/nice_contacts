import 'package:flutter/material.dart';
import 'package:my_contacts/screens/home_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/fake_call_scheduler_service.dart';
import 'package:my_contacts/services/preferences_service.dart';
import 'package:my_contacts/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService().init();
  // Start loading contacts early — all screens share this cache
  ContactsRepository().ensureLoaded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(PreferencesService().getAccentColor());
    return MaterialApp(
      navigatorKey: FakeCallSchedulerService.navigatorKey,
      title: 'Smart Contacts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor),
      darkTheme: AppTheme.dark(accentColor),
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
