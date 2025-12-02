import 'package:flutter/material.dart';
import 'package:sensor_data_app/data/sensor_packet.dart';
import 'package:sensor_data_app/data/serial_source.dart';
import '../widgets/graph_section.dart';
import 'app_menu.dart';
import 'dart:developer';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> ports = [];
  String? selectedPort = "COM1";
  int selectedBaudrate = 115200;
  bool isConnected = false;

  SerialSource? serial;
  SensorPacket? lastPacket;

  final baudrates = const [9600, 19200, 38400, 57600, 115200, 230400];

  @override
  void initState() {
    super.initState();
  }

  void connect() {
    if (selectedPort == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a port first')),
      );
      return;
    }
    try {
      serial = SerialSource(selectedPort!, selectedBaudrate);

      final success = serial!.connect((packet) {
        setState(() {
          lastPacket = packet;
          log('Packet: ${packet.payload.length} sensors at ${packet.timestamp}');
          for (var sensor in packet.payload) {
            log('  ${sensor.displayName}: ${sensor.data} ${sensor.displayUnit}');
          }
          // later: forward to GraphSection
        });
      });

      if (success) {
        setState(() {
          isConnected = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connected to $selectedPort')));
      } else {
        serial = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open serial port: $selectedPort')),
        );
      }
    } catch (e) {
      serial = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  void disconnect() {
    serial?.disconnect();
    serial = null;
    setState(() {
      isConnected = false;
    });
  }

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
                  value: selectedBaudrate,
                  items: baudrates
                      .map(
                        (baudrate) => DropdownMenuItem(
                          value: baudrate,
                          child: Text(baudrate.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: isConnected
                      ? null // lock when connected
                      : (value) {
                          setState(() {
                            selectedBaudrate = value!;
                          });
                        },
                ),

                const SizedBox(width: 24),

                const Text("Port:"),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedPort,
                  items: const [
                    DropdownMenuItem(value: "COM1", child: Text("COM1")),
                    DropdownMenuItem(value: "COM2", child: Text("COM2")),
                    DropdownMenuItem(value: "COM3", child: Text("COM3")),
                    DropdownMenuItem(value: "COM4", child: Text("COM4")),
                    DropdownMenuItem(value: "COM5", child: Text("COM5 ")),
                  ],
                  onChanged: isConnected
                      ? null // lock when connected
                      : (value) {
                          setState(() {
                            selectedPort = value!;
                          });
                        },
                ),

                const SizedBox(width: 24),

                ElevatedButton(
                  onPressed: isConnected ? disconnect : connect,
                  child: Text(isConnected ? "Disconnect" : "Connect"),
                ),
              ],
            ),
          ),

          const Expanded(child: GraphSection()),
        ],
      ),
    );
  }
}
