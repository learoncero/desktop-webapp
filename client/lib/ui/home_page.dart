import 'package:flutter/material.dart';
import '../widgets/graph_section.dart';
import 'app_menu.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Put the app menu into the appBar so it receives proper bounded constraints.
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppMenu(),
      ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[900],
            child: Row(
              children: [
                const Text("Baudrate:"),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: 9600,
                  items: const [
                    DropdownMenuItem(value: 9600, child: Text("9600")),
                    DropdownMenuItem(value: 19200, child: Text("19200")),
                    DropdownMenuItem(value: 38400, child: Text("38400")),
                    DropdownMenuItem(value: 57600, child: Text("57600")),
                    DropdownMenuItem(value: 115200, child: Text("115200")),
                  ],
                  onChanged: (value) {
                    // Handle baudrate change
                  },
                ),

                const SizedBox(width: 24),
                const Text("Port:"),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: "COM3",
                  items: const [
                    DropdownMenuItem(value: "COM1", child: Text("COM1")),
                    DropdownMenuItem(value: "COM2", child: Text("COM2")),
                    DropdownMenuItem(value: "COM3", child: Text("COM3")),
                    DropdownMenuItem(value: "COM4", child: Text("COM4")),
                  ],
                  onChanged: (value) {
                    // Handle port change
                  },
                ),

                const SizedBox(width: 24),
                ElevatedButton(
                  onPressed: () {
                    // Handle connect action
                  },
                  child: const Text("Connect"),
                ),
              ],
            ),
          ),

          const Expanded(
            child: GraphSection(),
          ),
        ],
      ),
    );
  }
}
