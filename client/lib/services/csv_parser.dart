import 'package:sensor_dash/models/sensor_packet.dart';

class CsvParser {
  static SensorPacket? parse(String line) {
    try {
      final parts = line.split(',').map((s) => s.trim()).toList();

      // CSV format: displayName1, displayUnit1, value1, displayName2, displayUnit2, value2, ...
      // Each sensor takes 3 values, so we need at least 3 parts and total must be divisible by 3
      if (parts.length < 3 || parts.length % 3 != 0) {
        return null;
      }

      final timestamp = DateTime.now();
      final payload = <SensorData>[];

      for (int i = 0; i < parts.length; i += 3) {
        final displayName = parts[i];
        final displayUnit = parts[i + 1];
        final valueStr = parts[i + 2];

        final value = double.tryParse(valueStr);
        if (value == null) {
          // Invalid value, skip this packet
          return null;
        }

        payload.add(
          SensorData(
            displayName: displayName,
            displayUnit: displayUnit,
            data: value,
          ),
        );
      }

      return SensorPacket(timestamp: timestamp, payload: payload);
    } catch (e) {
      // Invalid CSV format, ignore
    }
    return null;
  }
}
