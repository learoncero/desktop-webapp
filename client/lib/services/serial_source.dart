import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:sensor_dash/services/json_parser.dart';
import 'package:sensor_dash/services/csv_parser.dart';
import 'package:sensor_dash/models/sensor_packet.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import 'dart:async';

typedef PacketCallback = void Function(SensorPacket packet);
typedef ErrorCallback = void Function(String error);

class SerialSource {
  final String portName;
  final int baudRate;
  final bool simulate;
  final DataFormat dataFormat;
  SerialPort? port;
  SerialPortReader? reader;

  Timer? _simTimer;
  int _simCounter = 0;
  String _buffer = ''; // Buffer for incomplete lines

  SerialSource(
    this.portName,
    this.baudRate, {
    this.simulate = false,
    this.dataFormat = DataFormat.json,
  });

  bool connect({required PacketCallback onPacket, ErrorCallback? onError}) {
    if (simulate) {
      // Start simulation timer that emits a JSON-like packet every second
      _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _simCounter++;
        final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        // Create a payload with a couple of sensors and pseudo-random values
        final payload = [
          {
            'displayName': 'Temperature',
            'displayUnit': '°C',
            'data': 20 + (_simCounter % 5) + (0.1 * (_simCounter % 10)),
          },
          {
            'displayName': 'Humidity',
            'displayUnit': '%',
            'data': 40 + (_simCounter % 10),
          },
        ];
        final jsonLine = jsonEncode({'timestamp': ts, 'payload': payload});
        final packet = dataFormat == DataFormat.json
            ? JsonParser.parse(jsonLine)
            : null; // CSV simulation not implemented

        if (packet != null) {
          onPacket(packet);
        } else {
          // Don't call onError for parsing issues - just log and skip
          if (kDebugMode) {
            print(
              'Failed to parse simulated data as ${dataFormat.name.toUpperCase()}',
            );
          }
        }
      });

      return true;
    }

    try {
      port = SerialPort(portName);
      port!.config.baudRate = baudRate;

      if (!port!.openReadWrite()) {
        return false;
      }

      reader = SerialPortReader(port!);
      reader!.stream.listen(
        (data) {
          // Add incoming data to buffer
          _buffer += utf8.decode(data, allowMalformed: true);

          // Process all complete lines in the buffer
          while (_buffer.contains('\n')) {
            final newlineIndex = _buffer.indexOf('\n');
            final line = _buffer.substring(0, newlineIndex).trim();
            _buffer = _buffer.substring(newlineIndex + 1);

            if (line.isEmpty) {
              continue;
            }

            final packet = dataFormat == DataFormat.json
                ? JsonParser.parse(line)
                : CsvParser.parse(line);

            if (packet != null) {
              onPacket(packet);
            } else {
              // Parsing failed - wrong data format
              onError?.call(
                'Failed to parse received data as ${dataFormat.name.toUpperCase()}. '
                'Please check your data format settings.',
              );
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('Serial port error: $error');
          }
          if (onError != null) {
            onError('Connection lost: $error');
          }
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Serial connection exception: $e');
      }
      return false;
    }
  }

  void disconnect() {
    // Stop simulation if running
    try {
      _simTimer?.cancel();
    } catch (_) {}
    _simTimer = null;
    _simCounter = 0;
    _buffer = ''; // Clear buffer

    reader?.close();
    reader = null;
    port?.close();
    port = null;
  }
}
