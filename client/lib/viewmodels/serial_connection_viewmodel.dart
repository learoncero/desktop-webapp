import 'package:flutter/material.dart';
import 'package:sensor_data_app/models/sampled_value.dart';
import 'package:sensor_data_app/services/serial_source.dart';
import 'package:sensor_data_app/services/sampling_manager.dart';
import 'dart:developer';

class SerialConnectionViewModel extends ChangeNotifier {
  // Connection state
  String? _selectedPort = "COM1";
  int _selectedBaudrate = 115200;
  bool _isConnected = false;
  SerialSource? _serial;
  String? _errorMessage;

  // Sampling state
  SamplingManager? _samplingManager;
  String? _selectedSensorForPlot;
  String? _currentSensorUnit;
  SampledValue? _currentSample;
  List<String> _availableSensors = [];

  static const List<int> availableBaudrates = [
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
  ];

  static const List<String> availablePorts = [
    "COM1",
    "COM2",
    "COM3",
    "COM4",
    "COM5",
  ];

  // Getters
  String? get selectedPort => _selectedPort;
  int get selectedBaudrate => _selectedBaudrate;
  bool get isConnected => _isConnected;
  String? get selectedSensorForPlot => _selectedSensorForPlot;
  String? get currentSensorUnit => _currentSensorUnit;
  SampledValue? get currentSample => _currentSample;
  List<String> get availableSensors => _availableSensors;

  // Setters with notification
  void selectPort(String? port) {
    if (_isConnected) return;
    _selectedPort = port;
    notifyListeners();
  }

  void selectBaudrate(int baudrate) {
    if (_isConnected) return;
    _selectedBaudrate = baudrate;
    notifyListeners();
  }

  void selectSensorForPlot(String sensorName) {
    if (!_isConnected || !_availableSensors.contains(sensorName)) return;
    _selectedSensorForPlot = sensorName;
    _samplingManager?.selectSensor(sensorName);
    notifyListeners();
  }

  Future<String?> connect() async {
    if (_selectedPort == null) {
      _errorMessage = 'Please select a port first';
      notifyListeners();
      return _errorMessage;
    }

    if (_isConnected) {
      return null; // Already connected
    }

    try {
      // Initialize sampling manager (samples every 1 second)
      _samplingManager = SamplingManager(
        selectedSensorName: _selectedSensorForPlot,
        onSampleReady: (sensorName, unit, sample) {
          _selectedSensorForPlot = sensorName;
          _currentSensorUnit = unit;
          _currentSample = sample;
          notifyListeners();
        },
      );

      _serial = SerialSource(_selectedPort!, _selectedBaudrate);

      final success = _serial!.connect(
        onPacket: (packet) {
          _errorMessage = null;

          // Track available sensors from packet
          final sensorNames = packet.payload.map((s) => s.displayName).toList();
          if (_availableSensors.isEmpty) {
            _availableSensors = sensorNames;
            // Auto-select first sensor if none selected
            if (_selectedSensorForPlot == null && sensorNames.isNotEmpty) {
              _selectedSensorForPlot = sensorNames.first;
            }
          }

          _samplingManager?.addPacket(packet);

          log(
            'Packet: ${packet.payload.length} sensors at ${packet.timestamp}',
          );
          for (var sensor in packet.payload) {
            log(
              '  ${sensor.displayName}: ${sensor.data} ${sensor.displayUnit}',
            );
          }
        },
        onError: (error) {
          log('Serial error: $error');
          _errorMessage = 'Connection lost: Port $_selectedPort disconnected.';
          disconnect();
        },
      );

      if (success) {
        _isConnected = true;
        _errorMessage = null;
        notifyListeners();
        return null; // Success
      } else {
        _serial = null;
        _errorMessage = 'Failed to open serial port: $_selectedPort';
        notifyListeners();
        return _errorMessage;
      }
    } catch (e) {
      _serial = null;
      _errorMessage = 'Connection error: $e';
      notifyListeners();
      return _errorMessage;
    }
  }

  void disconnect() {
    if (_samplingManager != null) {
      _samplingManager!.dispose();
    }

    _serial?.disconnect();
    _serial = null;
    _samplingManager = null;
    _isConnected = false;
    _selectedSensorForPlot = null;
    _currentSensorUnit = null;
    _currentSample = null;
    _availableSensors = [];
    notifyListeners();

    log('Disconnected from serial port');
  }

  @override
  void dispose() {
    _samplingManager?.dispose();
    disconnect();
    super.dispose();
  }
}
