import 'dart:convert';
import 'package:sensor_data_app/data/sensor_packet.dart';

class SensorJsonParser {
  static SensorPacket? parse(String line) {
    try {
      final decoded = jsonDecode(line);

      if (decoded is Map<String, dynamic> && decoded.containsKey('payload')) {
        final timestamp = DateTime.now();
        final payloadList = decoded['payload'] as List;

        final payload = payloadList
            .map((item) => SensorData.fromJson(item as Map<String, dynamic>))
            .toList();

        return SensorPacket(timestamp: timestamp, payload: payload);
      }
    } catch (e) {
      // Invalid JSON, ignore
    }
    return null;
  }
}
