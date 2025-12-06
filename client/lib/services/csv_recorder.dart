import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sensor_data_app/models/sensor_packet.dart';

/// CsvRecorder writes sensor packets into a CSV file every second.
/// It subscribes to a packet stream and keeps the latest packet in memory.
/// Every second it writes a new CSV row with the packet's timestamp and values.
class CsvRecorder {
  final String folderPath;
  final Stream<SensorPacket> packetStream;
  final String baseFileName;

  StreamSubscription<SensorPacket>? _subscription;
  Timer? _timer;

  SensorPacket? _latestPacket;
  IOSink? _sink;
  File? _file;

  List<String>? _currentHeaderColumns;

  CsvRecorder({
    required this.folderPath,
    required this.packetStream,
    String? baseFileName,
  }) : baseFileName = baseFileName ?? 'sensor_record';

  Future<void> start() async {
    // Ensure folder exists
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Previously we created a file immediately here. Change: defer file creation until we have a header
    _sink = null;

    // Subscribe to incoming packets
    _subscription = packetStream.listen((pkt) {
      _onPacket(pkt);
    }, onError: (e) {
      // ignore for now
    });

    // Start periodic writer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        await _writeRowIfAvailable();
      } catch (e) {
        await stop();
      }
    });
  }

  Future<void> stop() async {
    try {
      _timer?.cancel();
    } catch (_) {}
    _timer = null;

    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
    _file = null;
    _latestPacket = null;
    _currentHeaderColumns = null;
  }

  void _onPacket(SensorPacket pkt) {
    // Update latest packet
    _latestPacket = pkt;

    // If header not written yet, write header based on this packet
    final header = _buildHeaderColumns(pkt);
    if (_currentHeaderColumns == null || !_listEquals(_currentHeaderColumns!, header)) {
      // If header changed, rotate file (close current and open new file)
      _rotateFileWithHeader(header);
    }
  }

  List<String> _buildHeaderColumns(SensorPacket pkt) {
    final cols = <String>[];
    cols.add('timestamp');
    for (var s in pkt.payload) {
      cols.add('${s.displayName} [${s.displayUnit}]');
    }
    return cols;
  }

  Future<void> _rotateFileWithHeader(List<String> header) async {
    // Close existing sink
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}

    // Create new file with timestamped name
    final now = DateTime.now();
    final timestamp = _formatDate(now);
    final filename = '${baseFileName}_$timestamp.csv';
    _file = File(p.join(folderPath, filename));
    _sink = _file!.openWrite(mode: FileMode.write);

    // Write header
    _currentHeaderColumns = header;
    final escaped = header.map((c) => '"' + c.replaceAll('"', '""') + '"').join(',');
    _sink!.writeln(escaped);
    await _sink!.flush();
  }

  Future<void> _writeRowIfAvailable() async {
    final pkt = _latestPacket;
    if (pkt == null) return; // nothing to write yet

    if (_sink == null || _currentHeaderColumns == null) {
      // No header/file yet; try to create from latest packet
      final header = _buildHeaderColumns(pkt);
      await _rotateFileWithHeader(header);
    }

    // Build row: timestamp (as unix seconds) + values
    final unix = pkt.timestamp.millisecondsSinceEpoch ~/ 1000;
    final values = <String>[];
    values.add(unix.toString());

    for (var s in pkt.payload) {
      values.add(s.data.toString());
    }

    final escaped = values.map((v) => '"' + v.replaceAll('"', '""') + '"').join(',');
    _sink!.writeln(escaped);
    await _sink!.flush();
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
