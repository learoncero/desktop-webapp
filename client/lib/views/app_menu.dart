import 'package:flutter/material.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';

class AppMenu extends StatefulWidget {
  const AppMenu({super.key});

  @override
  State<AppMenu> createState() => _AppMenuState();
}

class _AppMenuState extends State<AppMenu> {
  ThemeMode _currentThemeMode = ThemeMode.system;

  Future<void> _showAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';

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

  Future<void> _showSettings(BuildContext context) async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    groupValue: _currentThemeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        setState(() {
                          _currentThemeMode = value;
                        });
                        setDialogState(() {});
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MenuBarWidget(
            barButtons: [
              BarButton(
                text: const Text("File"),
                submenu: SubMenu(
                  menuItems: [
                    MenuButton(
                      text: const Text("Load CSV"),
                      onTap: () {
                        // Handle load CSV action
                      },
                    ),
                    const MenuDivider(),
                    MenuButton(
                      text: const Text("Exit"),
                      onTap: () {
                        // Handle exit action
                      },
                    ),
                  ],
                ),
              ),
              BarButton(
                text: const Text("Settings"),
                submenu: SubMenu(
                  menuItems: [
                    MenuButton(
                      text: const Text("Settings"),
                      onTap: () {
                        _showSettings(context);
                      },
                    ),
                  ],
                ),
              ),
              BarButton(
                text: const Text("Help"),
                submenu: SubMenu(
                  menuItems: [
                    MenuButton(
                      text: const Text("Help"),
                      onTap: () {
                        // Handle help action
                      },
                    ),
                    const MenuDivider(),
                    MenuButton(
                      text: const Text("About"),
                      onTap: () => _showAbout(context),
                    ),
                  ],
                ),
              ),
            ],

            child: Container(),
          ),
        ),
      ],
    );
  }
}
