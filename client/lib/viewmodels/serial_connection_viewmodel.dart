import 'package:flutter/material.dart';
import 'package:sensor_data_app/services/serial_source.dart';
import 'package:sensor_data_app/models/sensor_packet.dart';
import 'dart:developer';

class SerialConnectionViewModel extends ChangeNotifier {
  // Connection state
  String? _selectedPort = "COM1";
  int _selectedBaudrate = 115200;
  bool _isConnected = false;
  SerialSource? _serial;
  SensorPacket? _lastPacket;
  String? _errorMessage;

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
  SensorPacket? get lastPacket => _lastPacket;
  String? get errorMessage => _errorMessage;

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
      _serial = SerialSource(_selectedPort!, _selectedBaudrate);

      final success = _serial!.connect(
        onPacket: (packet) {
          _lastPacket = packet;
          _errorMessage = null;

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

  /// Disconnect from the serial port
  void disconnect() {
    _serial?.disconnect();
    _serial = null;
    _isConnected = false;
    _lastPacket = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
