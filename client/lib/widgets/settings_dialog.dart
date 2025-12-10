import 'package:flutter/material.dart';
import '../main.dart';

class SettingsDialog extends StatefulWidget {
  final ThemeMode currentThemeMode;

  const SettingsDialog({super.key, required this.currentThemeMode});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late ThemeMode _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentThemeMode;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          RadioGroup<ThemeMode>(
            groupValue: _selectedTheme,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                setState(() {
                  _selectedTheme = value;
                });
                MyApp.setThemeMode(context, value);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('System'),
                  leading: Radio<ThemeMode>(value: ThemeMode.system),
                ),
                ListTile(
                  title: const Text('Light'),
                  leading: Radio<ThemeMode>(value: ThemeMode.light),
                ),
                ListTile(
                  title: const Text('Dark'),
                  leading: Radio<ThemeMode>(value: ThemeMode.dark),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
