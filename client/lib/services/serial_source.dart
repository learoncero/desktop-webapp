import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:sensor_data_app/services/json_parser.dart';
import 'package:sensor_data_app/models/sensor_packet.dart';

typedef PacketCallback = void Function(SensorPacket packet);
typedef ErrorCallback = void Function(String error);

class SerialSource {
  final String portName;
  final int baudRate;
  SerialPort? port;
  SerialPortReader? reader;

  SerialSource(this.portName, this.baudRate);

  bool connect({required PacketCallback onPacket, ErrorCallback? onError}) {
    port = SerialPort(portName);
    port!.config.baudRate = baudRate;

    if (!port!.openReadWrite()) {
      return false;
    }

    reader = SerialPortReader(port!);
    reader!.stream.listen(
      (data) {
        final line = utf8.decode(data).trim();

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
  }

  void disconnect() {
    reader?.close();
    port?.close();
  }
}
