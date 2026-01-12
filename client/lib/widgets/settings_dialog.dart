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
  late DataFormat _selectedDataFormat;
  late ReductionMethod _reductionMethod;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentThemeMode;
    _visibleRange = widget.viewModel?.visibleRange ?? 60;
    _selectedDataFormat = widget.viewModel?.dataFormat ?? DataFormat.json;
    _reductionMethod =
        widget.viewModel?.reductionMethod ?? ReductionMethod.average;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 800,
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SettingsSection(
                      title: 'Appearance',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Theme', style: TextStyle(fontSize: 14)),
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
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: const Text('System'),
                                  leading: Radio<ThemeMode>(
                                    value: ThemeMode.system,
                                  ),
                                ),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: const Text('Light'),
                                  leading: Radio<ThemeMode>(
                                    value: ThemeMode.light,
                                  ),
                                ),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: const Text('Dark'),
                                  leading: Radio<ThemeMode>(
                                    value: ThemeMode.dark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.viewModel != null) ...[
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'Data Configuration',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data Format',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            RadioGroup<DataFormat>(
                              groupValue: _selectedDataFormat,
                              onChanged: widget.viewModel?.isConnected == true
                                  ? (_) {}
                                  : (DataFormat? value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedDataFormat = value;
                                        });
                                        widget.viewModel?.setDataFormat(value);
                                      }
                                    },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text('JSON'),
                                    leading: Radio<DataFormat>(
                                      value: DataFormat.json,
                                      enabled:
                                          widget.viewModel?.isConnected != true,
                                    ),
                                  ),
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text('CSV'),
                                    leading: Radio<DataFormat>(
                                      value: DataFormat.csv,
                                      enabled:
                                          widget.viewModel?.isConnected != true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.viewModel?.isConnected == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '(Cannot change while connected)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.viewModel != null) ...[
                      _SettingsSection(
                        title: 'Sampling',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reduction Method',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            RadioGroup<ReductionMethod>(
                              groupValue: _reductionMethod,
                              onChanged: widget.viewModel?.isRecording == true
                                  ? (_) {}
                                  : (ReductionMethod? value) {
                                      if (value != null) {
                                        setState(() {
                                          _reductionMethod = value;
                                        });
                                        widget.viewModel?.setReductionMethod(
                                          value,
                                        );
                                      }
                                    },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text('Average'),
                                    leading: Radio<ReductionMethod>(
                                      value: ReductionMethod.average,
                                      enabled:
                                          widget.viewModel?.isRecording != true,
                                    ),
                                  ),
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text('Maximum'),
                                    leading: Radio<ReductionMethod>(
                                      value: ReductionMethod.max,
                                      enabled:
                                          widget.viewModel?.isRecording != true,
                                    ),
                                  ),
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text('Minimum'),
                                    leading: Radio<ReductionMethod>(
                                      value: ReductionMethod.min,
                                      enabled:
                                          widget.viewModel?.isRecording != true,
                                    ),
                                  ),
                                ],
                              ),
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
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'Graph Settings',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Visible Range',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
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
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    '${_visibleRange.round()}s',
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
