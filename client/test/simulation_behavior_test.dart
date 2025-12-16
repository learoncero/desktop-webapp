import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sensor_data_app/services/serial_source.dart';
import 'package:sensor_data_app/viewmodels/serial_connection_viewmodel.dart';

class FakeSerialSource extends SerialSource {
  final bool _connectResult;
  FakeSerialSource(
    super.portName,
    super.baudRate, {
    super.simulate,
    bool connectResult = false,
  }) : _connectResult = connectResult;

  @override
  bool connect({required PacketCallback onPacket, ErrorCallback? onError}) {
    // Do not call super.connect to avoid native behavior
    return _connectResult;
  }

  @override
  void disconnect() {
    // noop
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no simulation by default when connection fails', () async {
    final vm = SerialConnectionViewModel(
      serialFactory: (port, baud, {simulate = false}) {
        // Always return a fake that fails to connect
        return FakeSerialSource(
          port,
          baud,
          simulate: simulate,
          connectResult: false,
        );
      },
    );

    // Ensure default behavior: connect() without flags should not simulate
    final err = await vm.connect();
    expect(err, isNotNull);
    expect(vm.isSimulated, isFalse);
  });

  test(
    'simulation only when injected (factory returns simulated source)',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('csvrec_test2');

      final vm = SerialConnectionViewModel(
        serialFactory: (port, baud, {simulate = false}) {
          // Return the real SerialSource in simulate mode for the test
          return SerialSource(port, baud, simulate: true);
        },
      );

      vm.setSaveFolderPath(tempDir.path);

      final err = await vm.connect();
      expect(err, isNull);
      expect(vm.isSimulated, isTrue);

      vm.startRecording();

      // Wait a bit for some packets and recording
      await Future.delayed(const Duration(seconds: 3));
      vm.disconnect();

      final files = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => p.extension(f.path).toLowerCase() == '.csv')
          .toList();

      expect(
        files.isNotEmpty,
        isTrue,
        reason:
            'CSV file should be created when simulation is active and folder is set',
      );

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    },
    timeout: Timeout(Duration(seconds: 20)),
  );
}
