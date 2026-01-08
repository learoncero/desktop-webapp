import 'dart:io';
import 'package:sensor_dash/services/json_parser.dart';
import 'package:sensor_dash/services/csv_parser.dart';
import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';

class UdpSource {
  final String address;
  final int port;
  final DataFormat dataFormat;

  RawDatagramSocket? _socket;

  UdpSource(this.address, this.port, {this.dataFormat = DataFormat.json});

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
            final message = String.fromCharCodes(datagram.data);

            final packet = dataFormat == DataFormat.json
                ? JsonParser.parse(message)
                : CsvParser.parse(message);

            if (packet != null) {
              onPacket(packet);
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
