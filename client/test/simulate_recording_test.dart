import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/viewmodels/serial_connection_viewmodel.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'simulate recording writes CSV files into selected folder',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('csvrec_test');
      final vm = SerialConnectionViewModel(
        serialFactory: (port, baud, {simulate = false, dataFormat = DataFormat.json}) {
          return SerialSource(
            port,
            baud,
            simulate: true,
            dataFormat: dataFormat,
          ); // TEST: always simulated
        },
      );

      // Set the save folder so recorder will start when connected
      vm.setSaveFolderPath(tempDir.path);

      // Connect: allowSimulationIfNoDevice is true by default, so it will fall back to simulation
      final err = await vm.connect();
      expect(
        err,
        isNull,
        reason: 'Connect (including simulation fallback) should succeed',
      );

      // Start recording
      vm.startRecording();

      // Wait a few seconds to allow the simulation to produce packets and recorder to write
      await Future.delayed(const Duration(seconds: 4));

      // Disconnect and stop recorder
      vm.disconnect();

      // Check for CSV files
      final files = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => p.extension(f.path).toLowerCase() == '.csv')
          .toList();

      expect(
        files.isNotEmpty,
        isTrue,
        reason: 'At least one CSV file should be created',
      );

      final content = files.first.readAsStringSync();

      final lines = content
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(
        lines.isNotEmpty,
        isTrue,
        reason: 'CSV must contain at least a header and one data row',
      );

      // Validate header line
      final headerParts = lines.first.split(',').map((s) => s.trim()).toList();

      expect(
        headerParts.length,
        equals(1 + 2 * 2), // 1 timestamp + 2 sensors * (unit + value)
        reason:
            'Header should contain timestamp plus unit/value columns for each sensor',
      );

      final expectedHeader = [
        'timestamp',
        'temperature_unit',
        'temperature_value',
        'humidity_unit',
        'humidity_value',
      ];

      expect(
        headerParts,
        equals(expectedHeader),
        reason: 'Header columns should match expected sensor columns in order',
      );

      // Validate first few data lines (after header)
      for (var i = 1; i < lines.length && i < 5; i++) {
        final line = lines[i];
        final parts = line.split(',');
        expect(
          parts.length,
          equals(expectedHeader.length),
          reason:
              'Each CSV data row should have ${expectedHeader.length} comma-separated fields',
        );

        // First field should be an integer unix timestamp
        final ts = parts[0].trim();
        expect(
          int.tryParse(ts),
          isNotNull,
          reason: 'First field should be a unix timestamp integer',
        );

        // The remaining fields (unit/value) should be quoted strings
        for (var j = 1; j < parts.length; j++) {
          final field = parts[j].trim();
          expect(
            field.startsWith('"') && field.endsWith('"'),
            isTrue,
            reason: 'Each unit/value field should be quoted',
          );

          // Ensure quoted field does not contain raw quotes inside (they should be escaped)
          final inner = field.substring(1, field.length - 1);
          expect(
            inner.contains('"'),
            isFalse,
            reason: 'Quoted field should not contain raw quotes',
          );
        }

        final tempUnit = parts[1].trim();
        final tempValue = parts[2].trim();
        final humUnit = parts[3].trim();
        final humValue = parts[4].trim();

        String unquote(String s) =>
            s.length >= 2 && s.startsWith('"') && s.endsWith('"')
            ? s.substring(1, s.length - 1)
            : s;

        expect(
          unquote(tempUnit),
          equals('°C'),
          reason: 'Temperature unit should be °C in simulation',
        );
        expect(
          unquote(humUnit),
          equals('%'),
          reason: 'Humidity unit should be % in simulation',
        );

        final tempNum = double.tryParse(unquote(tempValue));
        final humNum = double.tryParse(unquote(humValue));

        expect(
          tempNum,
          isNotNull,
          reason: 'Temperature value should be a number',
        );
        expect(humNum, isNotNull, reason: 'Humidity value should be a number');
      }

      // Additional checks: no duplicate timestamps and no rows that contain only empty sensor fields
      final dataLines = lines.skip(1).toList();

      // Check duplicates
      final timestamps = <int>[];
      for (final l in dataLines) {
        final p0 = l.split(',')[0].trim();
        final t = int.tryParse(p0);
        expect(t, isNotNull, reason: 'Data line timestamp should parse to int');
        timestamps.add(t!);
      }
      final uniqueTs = timestamps.toSet();
      expect(
        uniqueTs.length,
        equals(timestamps.length),
        reason: 'There should be no duplicate timestamps in CSV data rows',
      );

      // Check for completely empty sensor fields (all quoted empty strings)
      bool anyAllEmpty = false;
      for (final l in dataLines) {
        final parts = l.split(',').map((s) => s.trim()).toList();
        final sensorFields = parts.sublist(1); // exclude timestamp
        // If every sensor field is exactly an empty quoted string (""), then this row is empty
        final allEmpty = sensorFields.every((f) => f == '""');
        if (allEmpty) {
          anyAllEmpty = true;
          break;
        }
      }
      expect(
        anyAllEmpty,
        isFalse,
        reason:
            'There should be no data row where all sensor fields are empty (e.g., timestamp, "", "")',
      );

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    },
    timeout: Timeout(Duration(seconds: 20)),
  );
}
