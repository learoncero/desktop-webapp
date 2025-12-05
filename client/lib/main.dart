import 'package:flutter/material.dart';
import 'package:sensor_data_app/theme/app_theme.dart';
import 'views/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    context.findAncestorStateOfType<_MyAppState>()?.setThemeMode(mode);
  }
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Dashboard',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: const HomePage(),
    );
  }
}
