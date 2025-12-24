import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensor_dash/models/sampled_value.dart';
import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/services/sampling_manager.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:sensor_dash/services/csv_recorder.dart';
import 'package:sensor_dash/services/csv_loader.dart';
import 'package:sensor_dash/models/sensor_packet.dart';

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
  final CsvLoader _csvLoader = CsvLoader();

  // CSV playback state
  bool _isCsvMode = false;
  String? _loadedCsvPath;

  // Packet broadcast stream
  final StreamController<SensorPacket> _packetController =
      StreamController<SensorPacket>.broadcast();

  // Sampling state
  SamplingManager? _samplingManager;
  String? _selectedSensorForPlot;
  String? _currentSensorUnit;
  List<SampledValue>? _currentSamples;
  List<String> _availableSensors = [];

  // Plot
  final Map<String, List<FlSpot>> _graphPoints = {};
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
  bool get isCsvMode => _isCsvMode;
  String? get loadedCsvPath => _loadedCsvPath;

  Stream<SensorPacket> get packetStream => _packetController.stream;
  String? get selectedSensorForPlot => _selectedSensorForPlot;
  String? get currentSensorUnit => _currentSensorUnit;
  List<SampledValue>? get currentSamples => _currentSamples;
  List<String> get availableSensors => _availableSensors;
  Map<String, List<FlSpot>> get graphPoints => _graphPoints;
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
    if ((isCsvMode && _availableSensors.contains(sensorName)) ||
        (_isConnected && _availableSensors.contains(sensorName))) {
      _selectedSensorForPlot = sensorName;
      notifyListeners();
    }
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
    _resetGraphState();

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

          // Initialize sampling manager (samples every 1 second)
          _samplingManager = SamplingManager(
            onSampleReady: (samples) async {
              _currentSamples = samples;

              for (var sample in samples) {
                // Add sample to graph if recording
                addSampleToGraph(sample.dataStream, sample.value);
                _currentSensorUnit = sample.dataUnit;

                if (_graphStartTime.isEmpty && _isRecording) {
                  _graphStartTime =
                      "${sample.timestamp.toLocal().day.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().year} "
                      "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}";
                }

                // Forward sample to recorder if recording
                try {
                  if (_recorder != null && _isRecording) {
                    await _recorder!.recordSample(
                      sample.dataStream,
                      sample.dataUnit,
                      sample,
                    );
                  }
                } catch (e) {
                  // ignore recording errors for now
                }
              }

              if (_recorder != null && _isRecording) {
                _graphIndex += 1;
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
          onSampleReady: (samples) async {
            _currentSamples = samples;

            for (var sample in samples) {
              // Only add the selected sensor to the graph
              addSampleToGraph(sample.dataStream, sample.value);
              _currentSensorUnit = sample.dataUnit;

              if (_graphStartTime.isEmpty && _isRecording) {
                _graphStartTime =
                    "${sample.timestamp.toLocal().day.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().year} "
                    "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}";
              }

              // Forward sample to recorder if recording
              try {
                if (_recorder != null && _isRecording) {
                  // If recorder sensors aren't locked yet, lock them on first batch
                  if (!_recorder!.sensorsLocked) {
                    final initial = samples.map((s) => s.dataStream).toList();
                    _recorder!.setInitialSensors(initial);
                  }

                  await _recorder!.recordSample(
                    sample.dataStream,
                    sample.dataUnit,
                    sample,
                  );
                }
              } catch (e) {
                // ignore recording errors for now
              }
            }

            if (_recorder != null && _isRecording) {
              _graphIndex += 1;
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

          // Initialize sampling manager (samples every 1 second)
          _samplingManager = SamplingManager(
            onSampleReady: (samples) async {
              _currentSamples = samples;

              for (var sample in samples) {
                // Only add the selected sensor to the graph
                addSampleToGraph(sample.dataStream, sample.value);

                try {
                  if (_recorder != null && _isRecording) {
                    await _recorder!.recordSample(
                      sample.dataStream,
                      sample.dataUnit,
                      sample,
                    );
                  }
                } catch (e) {
                  // ignore recording errors for now
                }
              }

              if (_recorder != null && _isRecording) {
                _graphIndex += 1;
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
    return graphPoints[_selectedSensorForPlot]
            ?.where(
              (spot) =>
                  spot.x >= _visibleStart &&
                  spot.x <= _visibleStart + _visibleRange,
            )
            .toList() ??
        const [];
  }

  void addSampleToGraph(String dataStream, double value) {
    if (!_isRecording) return; // Only plot when recording
    _graphPoints.putIfAbsent(dataStream, () => []);
    _graphPoints[dataStream]!.add(FlSpot(_graphIndex.toDouble(), value));

    if (!_graphSliding) {
      _visibleStart = (_graphIndex - _visibleRange).clamp(0, double.infinity);
    }

    notifyListeners();
  }

  // Slider for Graph Plot
  double get maxGraphWindowStart {
    if ((_graphIndex - 1) <= _visibleRange) {
      return 0;
    }
    return ((_graphIndex - 1) - _visibleRange).toDouble();
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

    _resetGraphState();

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
      // Create recorder with a callback that sets an error message if sensors change
      _recorder = CsvRecorder(
        folderPath: _saveFolderPath!,
        onSensorsChanged: (newSensors) {
          _errorMessage =
              'Input sensors changed during recording: ${newSensors.join(', ')}';
          notifyListeners();
        },
      );
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

  void _resetGraphState({bool resetVisibleRange = false}) {
    _graphPoints.clear();
    _graphIndex = 0;
    _visibleStart = 0;
    _graphStartTime = "";
    _graphSliding = false;
    _availableSensors = [];
    _selectedSensorForPlot = null;
    _currentSensorUnit = null;
    if (resetVisibleRange) {
      _visibleRange = 60;
    }
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

  /// Load and display a CSV file
  /// This will disconnect from serial (if connected) and enter CSV playback mode
  Future<String?> loadCsvFile(String filePath) async {
    try {
      if (_isConnected) {
        disconnect();
      }

      // Reset state
      _resetGraphState();

      // Load CSV file
      final packets = await _csvLoader.loadCsvFile(filePath);

      if (packets.isEmpty) {
        _errorMessage = 'CSV file contains no valid data';
        notifyListeners();
        return _errorMessage;
      }

      // Extract available sensors from first packet
      final firstPacket = packets.first;
      _availableSensors = firstPacket.payload
          .map((s) => s.displayName)
          .toList();

      if (_availableSensors.isNotEmpty) {
        _selectedSensorForPlot = _availableSensors.first;
      }

      // Set graph start time
      _graphStartTime =
          "${firstPacket.timestamp.toLocal().day.toString().padLeft(2, '0')}.${firstPacket.timestamp.toLocal().month.toString().padLeft(2, '0')}.${firstPacket.timestamp.toLocal().year} "
          "${firstPacket.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${firstPacket.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${firstPacket.timestamp.toLocal().second.toString().padLeft(2, '0')}";

      // Convert packets to graph points
      for (final packet in packets) {
        for (final sensorData in packet.payload) {
          _graphPoints.putIfAbsent(sensorData.displayName, () => []);
          _graphPoints[sensorData.displayName]!.add(
            FlSpot(_graphIndex.toDouble(), sensorData.data),
          );

          // Update unit for selected sensor
          if (sensorData.displayName == _selectedSensorForPlot) {
            _currentSensorUnit = sensorData.displayUnit;
          }
        }
        _graphIndex += 1;
      }

      // Set last packet for display
      _lastPacket = packets.last;

      // Set visible range to show all data or max 60 points
      if (_graphIndex <= 60) {
        _visibleRange = _graphIndex.toDouble();
      } else {
        _visibleRange = 60;
      }
      _visibleStart = (_graphIndex - _visibleRange).clamp(0, double.infinity);

      // Enter CSV mode
      _isCsvMode = true;
      _loadedCsvPath = filePath;
      _isConnected = false;
      _isRecording = false;
      _errorMessage = null;

      notifyListeners();
      return null; // Success
    } catch (e) {
      _errorMessage = 'Failed to load CSV file: $e';
      _isCsvMode = false;
      _loadedCsvPath = null;
      notifyListeners();
      return _errorMessage;
    }
  }

  void closeCsvFile() {
    _isCsvMode = false;
    _loadedCsvPath = null;
    _resetGraphState(resetVisibleRange: true);
    _lastPacket = null;
    _errorMessage = null;
    notifyListeners();
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
