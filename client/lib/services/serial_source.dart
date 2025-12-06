import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:sensor_data_app/services/json_parser.dart';
import 'package:sensor_data_app/models/sensor_packet.dart';
import 'dart:async';
import 'dart:convert';

typedef PacketCallback = void Function(SensorPacket packet);
typedef ErrorCallback = void Function(String error);

class SerialSource {
  final String portName;
  final int baudRate;
  final bool simulate;
  SerialPort? port;
  SerialPortReader? reader;

  Timer? _simTimer;
  int _simCounter = 0;

  SerialSource(this.portName, this.baudRate, {this.simulate = false});

  bool connect({required PacketCallback onPacket, ErrorCallback? onError}) {
    if (simulate) {
      // Start simulation timer that emits a JSON-like packet every second
      _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _simCounter++;
        final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        // Create a payload with a couple of sensors and pseudo-random values
        final payload = [
          {
            'displayName': 'Temperature',
            'displayUnit': '°C',
            'data': 20 + (_simCounter % 5) + (0.1 * (_simCounter % 10))
          },
          {
            'displayName': 'Humidity',
            'displayUnit': '%',
            'data': 40 + (_simCounter % 10)
          }
        ];
        final jsonLine = jsonEncode({'timestamp': ts, 'payload': payload});
        final packet = SensorJsonParser.parse(jsonLine);
        if (packet != null) {
          onPacket(packet);
        }
      });

      return true;
    }

    try {
      port = SerialPort(portName);
      port!.config.baudRate = baudRate;

      if (!port!.openReadWrite()) {
        return false;
      }

      reader = SerialPortReader(port!);
      reader!.stream.listen(
        (data) {
          final line = String.fromCharCodes(data).trim();

          // Ignore lines that don't look like JSON (ESP log messages)
          if (!line.startsWith('{')) {
            return;
          }

          // Parse packet
          final packet = SensorJsonParser.parse(line);
          if (packet != null) {
            if (kDebugMode) {
              print('Parsed packet with ${packet.payload.length} sensors');
            }
            onPacket(packet);
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('Serial port error: $error');
          }
          if (onError != null) {
            onError('Connection lost: $error');
          }
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Serial connection exception: $e');
      }
      return false;
    }
  }

  void disconnect() {
    // Stop simulation if running
    try {
      _simTimer?.cancel();
    } catch (_) {}
    _simTimer = null;
    _simCounter = 0;

    reader?.close();
    reader = null;
    port?.close();
    port = null;
  }
}
