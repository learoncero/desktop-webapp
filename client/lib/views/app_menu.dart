import 'package:flutter/material.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppMenu extends StatelessWidget {
  const AppMenu({super.key});

  Future<void> _showAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';

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

  @override
  Widget build(BuildContext context) {
    return MenuBarWidget(
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
    );
  }
}
