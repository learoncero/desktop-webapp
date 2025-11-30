import 'package:flutter/material.dart';
import 'package:menu_bar/menu_bar.dart';

class AppMenu extends StatelessWidget {
  const AppMenu({super.key});

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
                  // UI only — no logic yet
                },
              ),
              const MenuDivider(),
              MenuButton(
                text: const Text("Exit"),
                onTap: () {
                  // Usually close the app
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
                  // UI only — maybe open a settings dialog
                },
              ),
            ],
          ),
        ),
      ],

      child: Container(),
    );
  }
}
