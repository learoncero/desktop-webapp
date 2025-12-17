import 'dart:async';
import 'package:sensor_data_app/models/sampled_value.dart';
import 'package:sensor_data_app/models/sensor_packet.dart';

class SamplingManager {
  static const int samplingIntervalSeconds = 1; // Sample every 1 second

  final Map<String, List<double>> _collectedValuesBySensor = {};
  final Map<String, String> _sensorUnits = {};
  Timer? _samplingTimer;

  // Callback for when new averaged samples are ready
  final void Function(List<SampledValue> samples) onSampleReady;

  SamplingManager({required this.onSampleReady}) {
    _startSampling();
  }

  void addPacket(SensorPacket packet) {
    if (packet.payload.isEmpty) {
      return;
    }

    for (final sensor in packet.payload) {
      final sensorName = sensor.displayName;

      _collectedValuesBySensor.putIfAbsent(sensorName, () => []);
      _sensorUnits[sensorName] = sensor.displayUnit;
      _collectedValuesBySensor[sensorName]!.add(sensor.data);
    }
  }

  void _startSampling() {
    _samplingTimer = Timer.periodic(
      Duration(seconds: samplingIntervalSeconds),
      (_) => _processSample(),
    );
  }

  void _processSample() {
    if (_collectedValuesBySensor.isEmpty) {
      return;
    }

    final sampledValues = <SampledValue>[];
    final timestamp = DateTime.now();

    for (final entry in _collectedValuesBySensor.entries) {
      final sensorName = entry.key;
      final values = entry.value;

      if (values.isEmpty) {
        continue;
      }

      final average = values.reduce((a, b) => a + b) / values.length;

      final sampledValue = SampledValue(
        dataStream: sensorName,
        dataUnit: _sensorUnits[sensorName] ?? '',
        timestamp: timestamp,
        value: average,
      );

      sampledValues.add(sampledValue);
    }

    _collectedValuesBySensor.clear();

    if (sampledValues.isNotEmpty) {
      onSampleReady(sampledValues);
    }
  }

  void clear() {
    _collectedValuesBySensor.clear();
    _sensorUnits.clear();
  }

  void dispose() {
    _samplingTimer?.cancel();
    _samplingTimer = null;
    clear();
  }
}
