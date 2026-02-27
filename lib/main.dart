import 'package:flutter/material.dart';
import 'package:my_contacts/screens/home_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/preferences_service.dart';

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
    return MaterialApp(
      title: 'My Contacts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(PreferencesService().getAccentColor()),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(PreferencesService().getAccentColor()),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
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
