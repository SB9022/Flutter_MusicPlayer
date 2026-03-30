import 'package:flutter/material.dart';
import 'package:music_player/home.dart';

final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.dark);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Music Player',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentThemeMode,
          home: HomePage(themeModeNotifier: _themeMode),
        );
      },
    );
  }
}
