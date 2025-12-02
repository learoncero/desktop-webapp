import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:sensor_data_app/data/json_parser.dart';
import 'package:sensor_data_app/data/sensor_packet.dart';

typedef PacketCallback = void Function(SensorPacket packet);

class SerialSource {
  final String portName;
  final int baudRate;
  SerialPort? port;
  SerialPortReader? reader;

  SerialSource(this.portName, this.baudRate);

  bool connect(PacketCallback onPacket) {
    port = SerialPort(portName);
    port!.config.baudRate = baudRate;

    if (!port!.openReadWrite()) {
      return false;
    }

    reader = SerialPortReader(port!);
    reader!.stream.listen((data) {
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
    });

    return true;
  }

  void disconnect() {
    reader?.close();
    port?.close();
  }
}
