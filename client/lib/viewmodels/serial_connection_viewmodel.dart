import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensor_data_app/models/sampled_value.dart';
import 'package:sensor_data_app/services/serial_source.dart';
import 'package:sensor_data_app/services/sampling_manager.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:sensor_data_app/services/csv_recorder.dart';
import 'package:sensor_data_app/models/sensor_packet.dart';

class SerialConnectionViewModel extends ChangeNotifier {
  final SerialSource Function(String port, int baud, {bool simulate})
  _serialFactory;

  SerialConnectionViewModel({
    SerialSource Function(String, int, {bool simulate})? serialFactory,
  }) : _serialFactory =
           serialFactory ??
           ((p, b, {simulate = false}) =>
               SerialSource(p, b, simulate: simulate)) {
    // Initialize a cross-platform default save folder (user can still change it)
    _initDefaultSaveFolder();
  }

  // Connection state
  String? _selectedPort = "COM1";
  int _selectedBaudrate = 115200;
  bool _isConnected = false;
  bool _isSimulated = false;
  bool _isRecording = false;
  SerialSource? _serial;
  String? _errorMessage;

  SensorPacket? _lastPacket;

  String? _saveFolderPath;
  CsvRecorder? _recorder;

  // Packet broadcast stream
  final StreamController<SensorPacket> _packetController =
      StreamController<SensorPacket>.broadcast();

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
  double _visibleRange = 60;
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
  bool get isSimulated => _isSimulated;
  bool get isRecording => _isRecording;
  SensorPacket? get lastPacket => _lastPacket;
  String? get errorMessage => _errorMessage;
  String? get saveFolderPath => _saveFolderPath;

  Stream<SensorPacket> get packetStream => _packetController.stream;
  String? get selectedSensorForPlot => _selectedSensorForPlot;
  String? get currentSensorUnit => _currentSensorUnit;
  SampledValue? get currentSample => _currentSample;
  List<String> get availableSensors => _availableSensors;
  List<FlSpot> get graphPoints => _graphPoints;
  double get visibleStart => _visibleStart;
  double get visibleRange => _visibleRange;
  bool get graphSliding => _graphSliding;
  String get graphStartTime => _graphStartTime;
  int get graphIndex => _graphIndex;

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

  void setVisibleRange(double range) {
    if (range < 10 || range > 300) return;
    _visibleRange = range;
    _visibleStart = (_graphIndex - _visibleRange).clamp(0, double.infinity);
    notifyListeners();
  }

  void selectSensorForPlot(String sensorName) {
    if (!_isConnected || !_availableSensors.contains(sensorName)) return;
    _selectedSensorForPlot = sensorName;
    _samplingManager?.selectSensor(sensorName);
    // reset graph when source changes
    _graphPoints.clear();
    _graphIndex = 0;
    _visibleStart = 0;
    _graphStartTime = "";
    notifyListeners();
  }

  /// Set the save folder path. If null, recording will stop.
  void setSaveFolderPath(String? path) {
    _saveFolderPath = path;
    notifyListeners();

    // Start/stop recorder depending on state
    _maybeStartRecorder();
  }

  void startRecording() {
    if (!_isConnected) return;

    // Reset graph for new recording session
    _graphPoints.clear();
    _graphIndex = 0;
    _visibleStart = 0;
    _graphStartTime = "";
    _graphSliding = false;

    _isRecording = true;
    _maybeStartRecorder(); // Start CSV recording
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    _stopRecorder(); // Stop CSV recording
    notifyListeners();
  }

  void toggleRecording() {
    if (_isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  }

  Future<String?> connect({
    bool allowSimulationIfNoDevice = false,
    bool forceSimulate = false,
  }) async {
    if (_selectedPort == null) {
      _errorMessage = 'Please select a port first';
      notifyListeners();
      return _errorMessage;
    }

    if (_isConnected) {
      return null; // Already connected
    }

    try {
      if (forceSimulate) {
        _serial = _serialFactory(
          _selectedPort!,
          _selectedBaudrate,
          simulate: true,
        );
        _isSimulated = true;
        final simSuccess = _serial!.connect(
          onPacket: (packet) {
            _lastPacket = packet;
            _errorMessage = null;
            try {
              _packetController.add(packet);
            } catch (_) {}
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = 'Simulation error: $error';
            notifyListeners();
          },
        );

        if (simSuccess) {
          _isConnected = true;
          _errorMessage = null;
          notifyListeners();

          // Initialize sampling manager now that we're connected (simulation)
          _samplingManager = SamplingManager(
            selectedSensorName: _selectedSensorForPlot,
            onSampleReady: (sensorName, unit, sample) async {
              _selectedSensorForPlot = sensorName;
              _currentSensorUnit = unit;
              _currentSample = sample;
              addSampleToGraph(sample.value);
              _graphStartTime = _graphStartTime.isNotEmpty
                  ? _graphStartTime
                  : "${sample.timestamp.toLocal().day.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().year} "
                        "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}";

              // Forward sample to recorder if recording
              try {
                if (_recorder != null) {
                  await _recorder!.recordSample(sensorName, unit, sample);
                }
              } catch (e) {
                // ignore recording errors for now
              }

              notifyListeners();
            },
          );

          _maybeStartRecorder();
          return null;
        } else {
          _serial = null;
          _errorMessage = 'Failed to start simulation';
          notifyListeners();
          return _errorMessage;
        }
      }

      // First try real serial (the factory may still return a simulated instance in tests)
      _serial = _serialFactory(
        _selectedPort!,
        _selectedBaudrate,
        simulate: false,
      );
      _isSimulated = _serial?.simulate ?? false;

      var success = _serial!.connect(
        onPacket: (packet) {
          _lastPacket = packet;
          _errorMessage = null;

          // Add to packet stream for any listeners (e.g., recorder)
          try {
            _packetController.add(packet);
          } catch (_) {}

          final sensorNames = packet.payload.map((s) => s.displayName).toList();
          if (_availableSensors.isEmpty) {
            _availableSensors = sensorNames;

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

      if (!success && allowSimulationIfNoDevice) {
        // Try simulation fallback via injected factory
        _serial = _serialFactory(
          _selectedPort!,
          _selectedBaudrate,
          simulate: true,
        );
        _isSimulated = _serial?.simulate ?? true;
        success = _serial!.connect(
          onPacket: (packet) {
            _lastPacket = packet;
            _errorMessage = null;
            try {
              _packetController.add(packet);
            } catch (_) {}
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = 'Simulation error: $error';
            notifyListeners();
          },
        );
      }

      if (success) {
        _isConnected = true;
        _errorMessage = null;

        // Initialize sampling manager (samples every 1 second)
        _samplingManager = SamplingManager(
          selectedSensorName: _selectedSensorForPlot,
          onSampleReady: (sensorName, unit, sample) async {
            _selectedSensorForPlot = sensorName;
            _currentSensorUnit = unit;
            _currentSample = sample;
            addSampleToGraph(sample.value);
            _graphStartTime = _graphStartTime.isNotEmpty
                ? _graphStartTime
                : "${sample.timestamp.toLocal().day.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().year} "
                      "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}";

            // Forward sample to recorder if recording
            try {
              if (_recorder != null) {
                await _recorder!.recordSample(sensorName, unit, sample);
              }
            } catch (e) {
              // ignore recording errors for now
            }

            notifyListeners();
          },
        );

        // Maybe start recorder if folder set
        _maybeStartRecorder();

        return null; // Success
      } else {
        _serial = null;
        _errorMessage = 'Failed to open serial port: $_selectedPort';
        notifyListeners();
        return _errorMessage;
      }
    } catch (e) {
      // If any unexpected exception, try simulation if allowed
      if (allowSimulationIfNoDevice) {
        _serial = _serialFactory(
          _selectedPort!,
          _selectedBaudrate,
          simulate: true,
        );
        _isSimulated = _serial?.simulate ?? true;
        final simSuccess = _serial!.connect(
          onPacket: (packet) {
            _lastPacket = packet;
            _errorMessage = null;
            try {
              _packetController.add(packet);
            } catch (_) {}
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = 'Simulation error: $error';
            notifyListeners();
          },
        );
        if (simSuccess) {
          _isConnected = true;
          _errorMessage = null;
          notifyListeners();

          // Initialize sampling manager for simulation fallback as well
          _samplingManager = SamplingManager(
            selectedSensorName: _selectedSensorForPlot,
            onSampleReady: (sensorName, unit, sample) async {
              _selectedSensorForPlot = sensorName;
              _currentSensorUnit = unit;
              _currentSample = sample;
              addSampleToGraph(sample.value);

              try {
                if (_recorder != null) {
                  await _recorder!.recordSample(sensorName, unit, sample);
                }
              } catch (e) {
                // ignore recording errors for now
              }

              notifyListeners();
            },
          );

          _maybeStartRecorder();
          return null;
        }
      }

      _serial = null;
      _isSimulated = false;
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
    if (!_isRecording) return; // Only plot when recording
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
    _isSimulated = false;
    _isRecording = false;
    _lastPacket = null;

    // Stop recorder if running
    _stopRecorder();

    _selectedSensorForPlot = null;
    _currentSensorUnit = null;
    _currentSample = null;
    _availableSensors = [];
    _graphIndex = 0;
    _visibleStart = 0;
    graphPoints.clear();
    _graphStartTime = "";

    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _maybeStartRecorder() {
    // Stop existing if no folder, not connected, or not recording
    if (!_isConnected || _saveFolderPath == null || !_isRecording) {
      _stopRecorder();
      return;
    }

    // Already started?
    if (_recorder != null) return;

    try {
      _recorder = CsvRecorder(folderPath: _saveFolderPath!);
      _recorder!.start();
    } catch (e) {
      _errorMessage = 'Failed to start recorder: $e';
      notifyListeners();
    }
  }

  void _stopRecorder() {
    try {
      _recorder?.stop();
    } catch (_) {}
    _recorder = null;
  }

  void _initDefaultSaveFolder() {
    // If user already set a folder, keep it
    if (_saveFolderPath != null) return;

    String? home;
    try {
      if (Platform.isWindows) {
        home =
            Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      } else {
        home = Platform.environment['HOME'];
      }
    } catch (_) {
      home = null;
    }

    if (home == null || home.isEmpty) return;

    final defaultPath = p.join(home, 'SensorDash', 'recordings');
    try {
      final dir = Directory(defaultPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _saveFolderPath = defaultPath;
      // Notify listeners so UI shows the default path; do not start recorder here
      notifyListeners();
    } catch (_) {
      // ignore errors silently; leave _saveFolderPath null
    }
  }

  @override
  void dispose() {
    _stopRecorder();
    _packetController.close();
    _samplingManager?.dispose();
    disconnect();
    super.dispose();
  }
}
