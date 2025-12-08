import 'package:fl_chart/fl_chart.dart';
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

  // Plot
  final List<FlSpot> _graphPoints = [];
  int _graphIndex = 0;
  double _visibleStart = 0;
  final double _visibleRange = 60;
  bool _graphSliding = false;
  String _graphStartTime = "";

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
  List<FlSpot> get graphPoints => _graphPoints;
  double get visibleStart => _visibleStart;
  double get visibleRange => _visibleRange;
  bool get graphSliding => _graphSliding;
  String get graphStartTime => _graphStartTime;

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
    // reset graph when source changes
    _graphPoints.clear();
    _graphIndex = 0;
    _graphStartTime = "";
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
          addSampleToGraph(sample.value);
          _graphStartTime = _graphStartTime.isNotEmpty
              ? _graphStartTime
              : "${sample.timestamp.toLocal().year}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().day.toString().padLeft(2, '0')} "
                    "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}";

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

  // Plot graph
  List<FlSpot> get visibleGraphPoints {
    return graphPoints.where((spot) {
      return spot.x >= _visibleStart && spot.x <= _visibleStart + _visibleRange;
    }).toList();
  }

  void addSampleToGraph(double value) {
    graphPoints.add(FlSpot(_graphIndex.toDouble(), value));
    _graphIndex++;
    if (!_graphSliding) {
      _visibleStart = (_graphIndex - _visibleRange).clamp(0, double.infinity);
    }
    notifyListeners();
  }

  // Slider for Graph Plot
  double get maxGraphWindowStart {
    if (graphPoints.length <= _visibleRange) return 0;
    return (graphPoints.length - _visibleRange).toDouble();
  }

  void updateVisibleStart(double value) {
    _graphSliding = true;
    _visibleStart = value;
    notifyListeners();
  }

  void resetGraph() {
    _graphSliding = false;
    _visibleStart = (_graphIndex - _visibleRange).clamp(0, double.infinity);
    notifyListeners();
  }

  // Disconnect from Data Source
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
    _graphIndex = 0;
    graphPoints.clear();
    _graphStartTime = "";

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
