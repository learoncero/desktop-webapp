import 'dart:io';
import 'package:csv/csv.dart';

import '../models/sensor_packet.dart';

class CsvLoader {
  Future<List<SensorPacket>> loadCsvFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final csvString = await file.readAsString();

    // Normalize line endings to handle different file formats
    final normalizedCsv = csvString
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final List<List<dynamic>> rows = const CsvToListConverter(
      fieldDelimiter: ',',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(normalizedCsv);

    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // Parse header to get sensor names
    final header = rows[0].map((e) => e.toString()).toList();
    if (header.isEmpty || header[0] != 'timestamp') {
      throw Exception(
        'Invalid CSV format: Expected "timestamp" as first column',
      );
    }

    // Extract sensor info from header
    // Format: timestamp, sensor1_unit, sensor1_value, sensor2_unit, sensor2_value, ...
    final List<String> sensorNames = [];
    for (int i = 1; i < header.length; i += 2) {
      final unitColumn = header[i];
      if (unitColumn.endsWith('_unit')) {
        final sensorName = unitColumn.substring(0, unitColumn.length - 5);
        sensorNames.add(sensorName);
      } else {
        throw Exception(
          'Invalid CSV format: Expected "_unit" column at position $i',
        );
      }
    }

    // Parse data rows
    final List<SensorPacket> packets = [];
    for (int rowIndex = 1; rowIndex < rows.length; rowIndex += 1) {
      final row = rows[rowIndex];
      if (row.isEmpty) continue;

      try {
        // Parse timestamp
        final timestampValue = row[0];
        final DateTime timestamp;
        if (timestampValue is int) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(
            timestampValue * 1000,
          );
        } else if (timestampValue is String) {
          final unixSeconds = int.parse(timestampValue);
          timestamp = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
        } else {
          throw Exception('Invalid timestamp format at row $rowIndex');
        }

        // Parse sensor data
        final List<SensorData> payload = [];
        for (int i = 0; i < sensorNames.length; i += 1) {
          final unitIndex = 1 + (i * 2);
          final valueIndex = unitIndex + 1;

          if (valueIndex >= row.length) {
            // Missing data for this sensor in this row, skip it
            continue;
          }

          final unit = row[unitIndex]?.toString() ?? '';
          final valueStr = row[valueIndex]?.toString() ?? '';

          if (unit.isEmpty || valueStr.isEmpty) {
            // Empty data, skip this sensor
            continue;
          }

          try {
            final value = double.parse(valueStr);
            payload.add(
              SensorData(
                displayName: _formatSensorName(sensorNames[i]),
                displayUnit: unit,
                data: value,
              ),
            );
          } catch (e) {
            // Skip invalid numeric values
            continue;
          }
        }

        if (payload.isNotEmpty) {
          packets.add(SensorPacket(timestamp: timestamp, payload: payload));
        }
      } catch (e) {
        // Skip invalid rows
        continue;
      }
    }

    return packets;
  }

  // e.g., "temperature" -> "Temperature", "humidity" -> "Humidity"
  String _formatSensorName(String normalizedName) {
    if (normalizedName.isEmpty) return normalizedName;
    return normalizedName[0].toUpperCase() + normalizedName.substring(1);
  }
}
