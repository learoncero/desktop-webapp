import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_selector/file_selector.dart';
import '../viewmodels/serial_connection_viewmodel.dart';
import '../widgets/settings_dialog.dart';
import '../main.dart';

class AppMenu extends StatelessWidget {
  final SerialConnectionViewModel? viewModel;

  const AppMenu({super.key, this.viewModel});

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

  Future<void> _loadCsvFile(BuildContext context) async {
    const XTypeGroup csvTypeGroup = XTypeGroup(
      label: 'CSV files',
      extensions: ['csv'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [csvTypeGroup]);

    if (file == null) {
      return; // User cancelled
    }

    if (viewModel == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: ViewModel not available')),
        );
      }
      return;
    }

    final error = await viewModel!.loadCsvFile(file.path);

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
          viewModel: viewModel,
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
                      onTap: () => _loadCsvFile(context),
                    ),
                    const MenuDivider(),
                    MenuButton(
                      text: const Text("Exit"),
                      onTap: () {
                        ServicesBinding.instance.exitApplication(
                          AppExitType.required,
                        );
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
