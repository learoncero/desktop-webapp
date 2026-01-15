import 'package:flutter_test/flutter_test.dart';
import 'package:sensor_dash/services/simulation_controller.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import 'package:sensor_dash/models/sensor_packet.dart';
import 'package:sensor_dash/models/sampled_value.dart';
import 'package:sensor_dash/models/sensor_packet.dart' as sp_models;
import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/services/csv_recorder.dart';

class FakeSerialSource extends SerialSource {
  FakeSerialSource(super.portName, super.baudRate, {super.simulate = false});

  @override
  bool connect({required void Function(SensorPacket) onPacket, ErrorCallback? onError}) {
    // do not emit anything automatically; indicate success
    return true;
  }

  @override
  void disconnect() {
    // noop
  }
}

class FakeCsvRecorder extends CsvRecorder {
  int recordCalls = 0;
  FakeCsvRecorder() : super(folderPath: '.', baseFileName: 'test', sensors: []);

  @override
  void setInitialSensors(List<String> initialSensors) {
    // call base but avoid file operations
    try {
      super.setInitialSensors(initialSensors);
    } catch (_) {}
  }

  @override
  Future<void> recordSample(String sensorName, String unit, SampledValue sample) async {
    recordCalls++;
    // Do not call super to avoid file IO
  }
}

void main() {
  test('SimulationController connects and exposes source and samplingManager', () {
    final controller = SimulationController(
      serialFactory: (p, b, {simulate = false, dataFormat = DataFormat.json}) => FakeSerialSource(p, b, simulate: simulate) as dynamic,
      port: 'COM1',
      baud: 115200,
    );

    final success = controller.connect(
      setLastPaket: (_) {},
      setErrorMessage: (_) {},
      addPacketToPacketController: (p) {},
      setCurrentSamples: (s) {},
      addSampleToGraph: (a, b, c) {},
      getGraphStartTime: () => '',
      isRecording: () => false,
      setGraphStartTime: (s) {},
      getRecorder: () => null,
      addToGraphIndex: (i) {},
      notifyListeners: () {},
    );

    expect(success, isTrue);
    expect(controller.source, isNotNull);
    expect(controller.samplingManager, isNotNull);
    expect(controller.isSimulated, isTrue);

    controller.dispose();
  });

  test('SimulationController routes samples to recorder and graph callbacks', () async {
    final controller = SimulationController(
      serialFactory: (p, b, {simulate = false, dataFormat = DataFormat.json}) => FakeSerialSource(p, b, simulate: simulate) as dynamic,
      port: 'COM1',
      baud: 115200,
    );

    List<List<SampledValue>> receivedSampleBatches = [];
    List<Map<String, dynamic>> graphAdds = [];
    String graphStart = '';

    final fakeRecorder = FakeCsvRecorder();

    final success = controller.connect(
      setLastPaket: (_) {},
      setErrorMessage: (_) {},
      addPacketToPacketController: (_) {},
      setCurrentSamples: (samples) => receivedSampleBatches.add(samples),
      addSampleToGraph: (stream, value, unit) => graphAdds.add({'stream': stream, 'value': value, 'unit': unit}),
      getGraphStartTime: () => graphStart,
      isRecording: () => true,
      setGraphStartTime: (s) => graphStart = s,
      getRecorder: () => fakeRecorder as dynamic,
      addToGraphIndex: (i) {},
      notifyListeners: () {},
    );

    expect(success, isTrue);
    final sm = controller.samplingManager!;

    final packet = sp_models.SensorPacket(
      timestamp: DateTime.now(),
      payload: [
        sp_models.SensorData(displayName: 'S1', displayUnit: 'u', data: 1.0),
        sp_models.SensorData(displayName: 'S2', displayUnit: 'u2', data: 2.0),
      ],
    );

    // Add packet to sampling manager which will trigger periodic sampling
    sm.addPacket(packet);

    // Wait slightly longer than the sampling interval to allow onSampleReady to fire
    await Future.delayed(const Duration(milliseconds: 1200));

    // Expect that at least one sample batch was delivered
    expect(receivedSampleBatches.length, greaterThanOrEqualTo(1));
    expect(graphAdds.length, greaterThanOrEqualTo(1));
    expect(fakeRecorder.recordCalls, greaterThanOrEqualTo(1));
    expect(graphStart.isNotEmpty, isTrue);

    controller.dispose();
  });
}
