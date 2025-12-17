import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sensor_data_app/services/serial_source.dart';
import 'package:sensor_data_app/viewmodels/serial_connection_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'simulate recording writes CSV files into selected folder',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('csvrec_test');
      final vm = SerialConnectionViewModel(
        serialFactory: (port, baud, {simulate = false}) {
          return SerialSource(
            port,
            baud,
            simulate: true,
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
        reason: 'Header should contain timestamp plus unit/value columns for each sensor',
      );

      final expectedHeader = [
        'timestamp',
        'temperature_unit',
        'temperature_value',
        'humidity_unit',
        'humidity_value'
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
          reason: 'Each CSV data row should have ${expectedHeader.length} comma-separated fields',
        );

        // First field should be an integer unix timestamp
        final ts = parts[0].trim();
        expect(int.tryParse(ts), isNotNull, reason: 'First field should be a unix timestamp integer');

        // The remaining fields (unit/value) should be quoted strings
        for (var j = 1; j < parts.length; j++) {
          final field = parts[j].trim();
          expect(
            field.startsWith('"') && field.endsWith('"'),
            isTrue,
            reason: 'Each unit/value field should be quoted',
          );

          // Ensure at least some data exists in the value fields (after removing quotes)
          final inner = field.substring(1, field.length - 1);
          expect(inner.contains('"'), isFalse, reason: 'Quoted field should not contain raw quotes');
        }
      }

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    },
    timeout: Timeout(Duration(seconds: 20)),
  );
}
