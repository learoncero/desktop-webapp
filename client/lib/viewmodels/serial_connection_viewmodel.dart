import 'package:flutter/material.dart';
import 'package:sensor_data_app/services/serial_source.dart';
import 'package:sensor_data_app/models/sensor_packet.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:sensor_data_app/services/csv_recorder.dart';

class SerialConnectionViewModel extends ChangeNotifier {
  final SerialSource Function(String port, int baud, {bool simulate}) _serialFactory;

  SerialConnectionViewModel({SerialSource Function(String, int, {bool simulate})? serialFactory})
      : _serialFactory = serialFactory ?? ((p, b, {simulate = false}) => SerialSource(p, b, simulate: simulate)) {
    // Initialize a cross-platform default save folder (user can still change it)
    _initDefaultSaveFolder();
  }

  // Connection state
  String? _selectedPort = "COM1";
  int _selectedBaudrate = 115200;
  bool _isConnected = false;
  bool _isSimulated = false;
  SerialSource? _serial;
  SensorPacket? _lastPacket;
  String? _errorMessage;

  String? _saveFolderPath;
  CsvRecorder? _recorder;

  // Packet broadcast stream
  final StreamController<SensorPacket> _packetController = StreamController<SensorPacket>.broadcast();

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
  SensorPacket? get lastPacket => _lastPacket;
  String? get errorMessage => _errorMessage;
  String? get saveFolderPath => _saveFolderPath;

  Stream<SensorPacket> get packetStream => _packetController.stream;

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

  /// Set the save folder path. If null, recording will stop.
  void setSaveFolderPath(String? path) {
    _saveFolderPath = path;
    notifyListeners();

    // Start/stop recorder depending on state
    _maybeStartRecorder();
  }

  Future<String?> connect({bool allowSimulationIfNoDevice = false, bool forceSimulate = false}) async {
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
        _serial = _serialFactory(_selectedPort!, _selectedBaudrate, simulate: true);
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
      _serial = _serialFactory(_selectedPort!, _selectedBaudrate, simulate: false);
      _isSimulated = _serial?.simulate ?? false;

      var success = _serial!.connect(
        onPacket: (packet) {
          _lastPacket = packet;
          _errorMessage = null;

          // Add to packet stream for any listeners (e.g., recorder)
          try {
            _packetController.add(packet);
          } catch (_) {}

          // Log the packet
          log(
            'Packet: ${packet.payload.length} sensors at ${packet.timestamp}',
          );
          for (var sensor in packet.payload) {
            log(
              '  ${sensor.displayName}: ${sensor.data} ${sensor.displayUnit}',
            );
          }

          notifyListeners();
        },
        onError: (error) {
          log('Serial error: $error');
          _errorMessage = 'Connection lost: Port $_selectedPort disconnected.';
          disconnect();
        },
      );

      if (!success && allowSimulationIfNoDevice) {
        // Try simulation fallback via injected factory
        _serial = _serialFactory(_selectedPort!, _selectedBaudrate, simulate: true);
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
        notifyListeners();

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
        _serial = _serialFactory(_selectedPort!, _selectedBaudrate, simulate: true);
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

  /// Disconnect from the serial port
  void disconnect() {
    _serial?.disconnect();
    _serial = null;
    _isConnected = false;
    _isSimulated = false;
    _lastPacket = null;

    // Stop recorder if running
    _stopRecorder();

    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _maybeStartRecorder() {
    // Stop existing if no folder or not connected
    if (!_isConnected || _saveFolderPath == null) {
      _stopRecorder();
      return;
    }

    // Already started?
    if (_recorder != null) return;

    try {
      _recorder = CsvRecorder(folderPath: _saveFolderPath!, packetStream: packetStream);
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
        home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      } else {
        home = Platform.environment['HOME'];
      }
    } catch (_) {
      home = null;
    }

    if (home == null || home.isEmpty) return;

    final defaultPath = p.join(home, 'SensorDataApp', 'recordings');
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
    disconnect();
    super.dispose();
  }
}
