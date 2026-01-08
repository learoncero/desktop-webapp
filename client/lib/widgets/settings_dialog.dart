import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import 'package:sensor_dash/services/sampling_manager.dart';
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
  late ReductionMethod _reductionMethod;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentThemeMode;
    _visibleRange = widget.viewModel?.visibleRange ?? 60;
    _reductionMethod =
        widget.viewModel?.reductionMethod ?? ReductionMethod.average;
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
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Reduction Method:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 16),
                DropdownButton<ReductionMethod>(
                  value: _reductionMethod,
                  onChanged: widget.viewModel?.isRecording == true
                      ? null
                      : (ReductionMethod? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _reductionMethod = newValue;
                            });
                            widget.viewModel?.setReductionMethod(newValue);
                          }
                        },
                  items: const [
                    DropdownMenuItem(
                      value: ReductionMethod.average,
                      child: Text('Average'),
                    ),
                    DropdownMenuItem(
                      value: ReductionMethod.max,
                      child: Text('Maximum'),
                    ),
                    DropdownMenuItem(
                      value: ReductionMethod.min,
                      child: Text('Minimum'),
                    ),
                  ],
                ),
              ],
            ),
            if (widget.viewModel?.isRecording == true)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '(Cannot change while recording)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
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
