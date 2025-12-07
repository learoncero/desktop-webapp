import 'dart:async';
import 'package:sensor_data_app/models/sampled_value.dart';
import 'package:sensor_data_app/models/sensor_packet.dart';

class SamplingManager {
  static const int samplingIntervalSeconds = 1; // Sample every 1 second

  String? _selectedSensorName;
  String? _currentSensorUnit;
  final List<double> _collectedValues = [];
  Timer? _samplingTimer;

  // Callback for when new averaged sample is ready
  final void Function(String sensorName, String unit, SampledValue sample)
  onSampleReady;

  SamplingManager({String? selectedSensorName, required this.onSampleReady})
    : _selectedSensorName = selectedSensorName {
    _startSampling();
  }

  /// Add a packet - collects the value for the selected sensor
  void addPacket(SensorPacket packet) {
    if (packet.payload.isEmpty) return;

    // If no sensor is selected yet, select the first one
    _selectedSensorName ??= packet.payload.first.displayName;

    // Find the selected sensor in the packet
    final sensor = packet.payload.firstWhere(
      (s) => s.displayName == _selectedSensorName,
      orElse: () => packet.payload.first,
    );

    _currentSensorUnit = sensor.displayUnit;
    _collectedValues.add(sensor.data);
  }

  void selectSensor(String sensorName) {
    if (_selectedSensorName == sensorName) return;

    _selectedSensorName = sensorName;
    clear();
  }

  void _startSampling() {
    _samplingTimer = Timer.periodic(
      Duration(seconds: samplingIntervalSeconds),
      (_) => _processSample(),
    );
  }

  /// Process all collected values, calculate average, and notify
  void _processSample() {
    if (_selectedSensorName == null || _collectedValues.isEmpty) return;

    // Calculate average over ALL values collected in this interval
    final values = List<double>.from(_collectedValues);
    final average = values.reduce((a, b) => a + b) / values.length;

    final sampledValue = SampledValue(
      timestamp: DateTime.now(),
      value: average,
      sampleCount: values.length,
    );

    // Clear collected values for next interval
    _collectedValues.clear();

    onSampleReady(_selectedSensorName!, _currentSensorUnit ?? '', sampledValue);
  }

  String? get selectedSensorName => _selectedSensorName;

  void clear() {
    _collectedValues.clear();
    _currentSensorUnit = null;
  }

  void dispose() {
    _samplingTimer?.cancel();
    _samplingTimer = null;
    clear();
  }
}
