import 'package:flutter/material.dart';
import 'package:my_contacts/screens/home_screen.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/services/fake_call_scheduler_service.dart';
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
    final accentColor = Color(PreferencesService().getAccentColor());
    return MaterialApp(
      navigatorKey: FakeCallSchedulerService.navigatorKey,
      title: 'Smart Contacts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: accentColor,
              brightness: Brightness.light,
            ).copyWith(
              tertiary: _shiftHue(accentColor, 45),
              tertiaryContainer: _shiftHue(
                accentColor,
                45,
              ).withValues(alpha: 0.15),
            ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: accentColor,
              brightness: Brightness.dark,
            ).copyWith(
              tertiary: _shiftHue(accentColor, 45),
              tertiaryContainer: _shiftHue(
                accentColor,
                45,
              ).withValues(alpha: 0.15),
            ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: _getThemeMode(),
      home: const HomeScreen(),
    );
  }

  /// Rotate hue of a color by [degrees]
  static Color _shiftHue(Color color, double degrees) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + degrees) % 360).toColor();
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
