import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:sensor_dash/viewmodels/serial_connection_viewmodel.dart';
import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/models/sensor_packet.dart';

// Fake serial source that allows the test to push packets manually.
class FakeSerialSource extends SerialSource {
  late PacketCallback _onPacket;
  bool _connected = false;

  FakeSerialSource(super.portName, super.baudRate, {super.simulate});

  @override
  bool connect({required PacketCallback onPacket, ErrorCallback? onError}) {
    _onPacket = onPacket;
    _connected = true;
    return true;
  }

  void sendPacket(SensorPacket pkt) {
    if (_connected) {
      _onPacket(pkt);
    }
  }

  @override
  void disconnect() {
    _connected = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ViewModel sets error when input sensors change during recording',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('csvrec_test');

      late FakeSerialSource fake;
      final vm = SerialConnectionViewModel(
        serialFactory: (port, baud, {simulate = false}) {
          fake = FakeSerialSource(port, baud, simulate: simulate);
          return fake;
        },
      );

      // Prepare save folder so recorder can start
      vm.setSaveFolderPath(tempDir.path);

      final err = await vm.connect();
      expect(err, isNull, reason: 'Connect should succeed');

      vm.startRecording();

      // Send initial packet with Temperature + Humidity
      final pkt1 = SensorPacket(
        timestamp: DateTime.now(),
        payload: [
          SensorData(displayName: 'Temperature', displayUnit: '°C', data: 21.0),
          SensorData(displayName: 'Humidity', displayUnit: '%', data: 50.0),
        ],
      );

      fake.sendPacket(pkt1);

      // Wait for sampling manager to aggregate and forward samples (~1s)
      await Future.delayed(const Duration(seconds: 2));

      // No error expected yet
      expect(vm.errorMessage, isNull);

      // Now send a packet that includes an additional sensor
      final pkt2 = SensorPacket(
        timestamp: DateTime.now(),
        payload: [
          SensorData(displayName: 'Temperature', displayUnit: '°C', data: 22.0),
          SensorData(displayName: 'Humidity', displayUnit: '%', data: 49.0),
          SensorData(
            displayName: 'Accelerometer',
            displayUnit: 'g',
            data: 0.12,
          ),
        ],
      );

      fake.sendPacket(pkt2);

      // Wait again for sampling manager to process
      await Future.delayed(const Duration(seconds: 2));

      expect(
        vm.errorMessage,
        equals('Input sensors changed during recording: Accelerometer'),
        reason:
            'ViewModel should set error when new sensor appears during recording',
      );

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    },
    timeout: Timeout(Duration(seconds: 20)),
  );
}
