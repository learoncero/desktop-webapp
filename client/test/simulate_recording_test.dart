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
      expect(
        content.contains('timestamp'),
        isTrue,
        reason: 'CSV header should contain timestamp',
      );

      // Cleanup
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    },
    timeout: Timeout(Duration(seconds: 20)),
  );
}
