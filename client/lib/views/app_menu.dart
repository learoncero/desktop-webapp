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

  void _toggleTheme() {
    setState(() {
      if (_currentThemeMode == ThemeMode.light) {
        _currentThemeMode = ThemeMode.dark;
      } else if (_currentThemeMode == ThemeMode.dark) {
        _currentThemeMode = ThemeMode.light;
      } else {
        final brightness = MediaQuery.of(context).platformBrightness;
        _currentThemeMode = brightness == Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark;
      }
    });
    MyApp.setThemeMode(context, _currentThemeMode);
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
                      text: const Text("Switch Theme"),
                      onTap: _toggleTheme,
                    ),
                    const MenuDivider(),
                    MenuButton(
                      text: const Text("Settings"),
                      onTap: () {
                        // Handle settings action
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
