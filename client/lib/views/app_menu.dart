import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import '../widgets/settings_dialog.dart';
import '../main.dart';

class AppMenu extends StatelessWidget implements PreferredSizeWidget {
  final ThemeMode currentThemeMode;
  final ConnectionBaseViewModel? connectionBaseViewModel;

  const AppMenu({
    super.key,
    required this.currentThemeMode,
    this.connectionBaseViewModel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(30);

  Future<void> _showAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final version = 'v${info.version}';

    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Sensor Data App',
      applicationVersion: version,
      children: [
        const SizedBox(height: 8),
        const Text('Creators: Roncero, Schneider, Schönberger'),
        Text('Version: $version'),
      ],
    );
  }

  Future<void> _loadCsvFile(BuildContext context) async {
    const XTypeGroup csvTypeGroup = XTypeGroup(
      label: 'CSV files',
      extensions: ['csv'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [csvTypeGroup]);

    if (file == null) {
      return; // User cancelled
    }

    if (connectionBaseViewModel == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: ViewModel not available')),
        );
      }
      return;
    }

    final error = await connectionBaseViewModel!.loadCsvFile(file.path);

    if (context.mounted) {
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading CSV: $error')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV loaded: ${file.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showSettings(BuildContext context) async {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SettingsDialog(
          currentThemeMode: MyApp.getThemeMode(context),
          viewModel: connectionBaseViewModel,
        );
      },
    );
  }

  Future<void> _showHelp(BuildContext context) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Help — Application Guide'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This application captures, visualizes and optionally records sensor data coming from serial or UDP sources. It provides a live graph, connection management, and CSV recording for later analysis. The interface is optimized for desktop use (Windows/macOS/Linux).',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Usage',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1. Select a connection type from the menu (Serial or UDP).\n'
                  '2. Configure the connection parameters (port/address, baud rate, sample format).\n'
                  '3. Click Connect to begin receiving live data. Live plots update in real time.\n'
                  '4. To record data, open the Recording controls (menu or toolbar) and enable CSV recording before or during a session. Recorded files are saved to the configured folder.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'CSV recording behavior',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '- Each recorded CSV row represents one sample set with a timestamp and sensor values.\n'
                  "- Files are created per recording session; if a recording is restarted a new file is created.\n"
                  "- CSV uses UTF-8 encoding and comma delimiters. Time format uses ISO 8601 (UTC).\n"
                  "- When disk is full or write errors occur, recording stops and an error notification is shown.",
                ),
                const SizedBox(height: 12),
                const Text(
                  'Known limitations',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '- Real-time plotting is intended for moderate sample rates; very high rates may drop frames or samples.\n'
                  "- Serial port detection depends on OS drivers; some devices may require additional drivers.\n"
                  "- UDP reception is best-effort; packet loss on the network will result in missing samples.\n"
                  "- There is no built-in data replay UI — use the CSV files for offline analysis.",
                ),
                const SizedBox(height: 12),
                const Text(
                  'Troubleshooting',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '- No data shown after Connect: verify cable/device power, correct port/baud and that only one process uses the port.\n'
                  "- Unexpected CSV format: check recording settings and look at the first lines of the CSV file with a text editor.\n"
                  "- App does not detect serial ports on Windows: try restarting the machine or reinstalling the device driver; run the app as Administrator if permissions are restricted.\n"
                  "- If the graph freezes or becomes slow: try lowering sample rate or filter out unused channels. Restarting the app can help recover from resource leaks.",
                ),
                const SizedBox(height: 40),
                const Text(
                  'Support & Feedback',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'If problems persist, consult the project README or open an issue on GitHub: https://github.com/learoncero/desktop-webapp with logs and a short description of steps to reproduce.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 30, // definite height for the app bar area
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // File menu
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: '',
                menuPadding: EdgeInsets.zero,
                position: PopupMenuPosition.under,
                child: _HoverMenuLabel(label: 'File'),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'load',
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('Load CSV'),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'exit',
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('Exit'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'load') {
                    _loadCsvFile(context);
                  } else if (value == 'exit') {
                    ServicesBinding.instance.exitApplication(
                      AppExitType.required,
                    );
                  }
                },
              ),

              // Settings menu
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: '',
                menuPadding: EdgeInsets.zero,
                position: PopupMenuPosition.under,
                child: _HoverMenuLabel(label: 'Settings'),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('Settings'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'settings') _showSettings(context);
                },
              ),

              // Help menu
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: '',
                menuPadding: EdgeInsets.zero,
                position: PopupMenuPosition.under,
                child: _HoverMenuLabel(label: 'Help'),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'help',
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('Help'),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'about',
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('About'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'help') _showHelp(context);
                  if (value == 'about') _showAbout(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverMenuLabel extends StatefulWidget {
  final String label;
  const _HoverMenuLabel({required this.label});

  @override
  State<_HoverMenuLabel> createState() => _HoverMenuLabelState();
}

class _HoverMenuLabelState extends State<_HoverMenuLabel> {
  bool _hover = false;

  void _onEnter(PointerEnterEvent _) => setState(() => _hover = true);
  void _onExit(PointerExitEvent _) => setState(() => _hover = false);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final int a = (0.10 * 255).round();
    final int r = ((onSurface.r * 255.0).round()).clamp(0, 255);
    final int g = ((onSurface.g * 255.0).round()).clamp(0, 255);
    final int b = ((onSurface.b * 255.0).round()).clamp(0, 255);
    final overlay = Color.fromARGB(a, r, g, b);
    final hoverColor = _hover
        ? Color.alphaBlend(overlay, base)
        : Colors.transparent;

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 0),
        child: SizedBox(
          height: double.infinity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: hoverColor,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
