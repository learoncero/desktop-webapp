import 'dart:convert';

import 'package:sensor_data_app/data/sensor_packet.dart';

class SensorJsonParser {
  static SensorPacket? parse(String line) {
    try {
      final decoded = jsonDecode(line);

      if (decoded is Map<String, dynamic>) {
        return SensorPacket(timestamp: DateTime.now(), values: decoded);
      }

      return null;
    } catch (e) {
      // invalid JSON, ignore
    }
    return null;
  }
}
