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
      ],

      child: Container(),
    );
  }
}
