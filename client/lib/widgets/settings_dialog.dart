import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import '../main.dart';

class SettingsDialog extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ConnectionBaseViewModel? viewModel;

  const SettingsDialog({
    super.key,
    required this.currentThemeMode,
    this.viewModel,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late ThemeMode _selectedTheme;
  late double _visibleRange;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentThemeMode;
    _visibleRange = widget.viewModel?.visibleRange ?? 60;
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
          if (widget.viewModel != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Graph Window',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Visible Range:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _visibleRange,
                    min: 10,
                    max: 300,
                    divisions: 29,
                    label: '${_visibleRange.round()}s',
                    onChanged: (value) {
                      setState(() {
                        _visibleRange = value;
                      });
                      widget.viewModel?.setVisibleRange(value);
                    },
                  ),
                ),
                Text('${_visibleRange.round()}s'),
              ],
            ),
          ],
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
