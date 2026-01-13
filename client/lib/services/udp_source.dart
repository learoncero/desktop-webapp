import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sensor_dash/services/json_parser.dart';
import 'package:sensor_dash/services/csv_parser.dart';
import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';

class UdpSource {
  final String address;
  final int port;
  final DataFormat dataFormat;

  RawDatagramSocket? _socket;

  UdpSource(this.address, this.port, {required this.dataFormat});

  Future<bool> connect({
    required PacketCallback onPacket,
    ErrorCallback? onError,
  }) async {
    try {
      final bindAddress = address == '0.0.0.0'
          ? InternetAddress.anyIPv4
          : InternetAddress(address);

      _socket = await RawDatagramSocket.bind(bindAddress, port);

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            // Decode as Latin-1 first, then re-encode as UTF-8 to fix encoding issues
            var message = latin1.decode(datagram.data);
            message = utf8
                .decode(latin1.encode(message), allowMalformed: true)
                .trim();

            if (message.isEmpty) {
              return;
            }

            final packet = dataFormat == DataFormat.json
                ? JsonParser.parse(message)
                : CsvParser.parse(message);

            if (packet != null) {
              if (kDebugMode) {
                print(
                  'Parsed UDP packet with ${packet.payload.length} sensors',
                );
              }
              onPacket(packet);
            } else {
              if (kDebugMode) {
                print('Failed to parse UDP message as $dataFormat: $message');
              }
              onError?.call(
                'Failed to parse received data as ${dataFormat.name.toUpperCase()}. '
                'Please check your data format settings.',
              );
            }
          }
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  void disconnect() {
    if (_socket == null) {
      return;
    }

    _socket!.close();
    _socket = null;
  }
}
