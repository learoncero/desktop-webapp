import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sensor_data_app/models/sampled_value.dart';

class CsvRecorder {
  final String folderPath;
  final String baseFileName;

  // List of expected sensor names in the order they should appear in the CSV.
  final List<String> sensors;

  IOSink? _sink;
  File? _file;
  bool _started = false;

  final Map<int, Map<String, Map<String, String>>> _pending = {};

  CsvRecorder({required this.folderPath, String? baseFileName, List<String>? sensors})
      : baseFileName = baseFileName ?? 'sensor_record',
        sensors = sensors ?? const ['temperature', 'humidity'];

  Future<void> start() async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _started = true;
  }

  Future<void> stop() async {
    _started = false;
    try {
      await _flushRemaining(); // Write any remaining partial rows before closing.
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
    _file = null;
    _pending.clear();
  }

  /// Record a prepared sample into the CSV. This method is safe to call even
  /// if the recorder hasn't been started; it will try to create the folder
  /// on demand. Rows are written only when all expected sensors for a
  /// timestamp have been received (one row per unix-second timestamp). Partial
  /// rows are flushed when `stop()` is called.
  Future<void> recordSample(
    String sensorName,
    String unit,
    SampledValue sample,
  ) async {
    if (!_started) {
      // Try to auto-start so callers don't have to manage ordering strictly
      await start();
    }

    // Ensure the output file/sink exists and header has been written.
    await _ensureFileOpen(sample.timestamp);

    final unix = sample.timestamp.millisecondsSinceEpoch ~/ 1000;

    _pending.putIfAbsent(unix, () => {});
    _pending[unix]![sensorName] = {
      'unit': unit,
      'value': sample.value.toString(),
    };

    if (_pending[unix]!.length == sensors.length) {
      await _writeRowForTimestamp(unix);
    }
  }

  Future<void> _ensureFileOpen(DateTime now) async {
    if (_sink != null) return;

    final timestamp = _formatDate(now);
    final filename = '${baseFileName}_$timestamp.csv';
    _file = File(p.join(folderPath, filename));
    _sink = _file!.openWrite(mode: FileMode.write);

    // Write header line according to the configured sensors.
    _writeHeader();
  }

  void _writeHeader() {
    if (_sink == null) return;
    final parts = <String>[];
    parts.add('timestamp');
    for (final s in sensors) {
      parts.add('${s}_unit');
      parts.add('${s}_value');
    }
    _sink!.writeln(parts.join(','));
  }

  Future<void> _writeRowForTimestamp(int unix) async {
    final rowMap = _pending[unix];
    if (rowMap == null) return;

    final values = <String>[];
    values.add(unix.toString());
    for (final s in sensors) {
      final entry = rowMap[s];
      if (entry != null) {
        values.add(_escapeForCsv(entry['unit'] ?? ''));
        values.add(_escapeForCsv(entry['value'] ?? ''));
      } else {
        values.add(_escapeForCsv(''));
        values.add(_escapeForCsv(''));
      }
    }

    _sink!.writeln(values.join(','));
    await _sink!.flush();

    _pending.remove(unix);
  }

  String _escapeForCsv(String v) => '"${v.replaceAll('"', '""')}"';

  Future<void> _flushRemaining() async {
    if (_pending.isEmpty) return;
    final keys = _pending.keys.toList()..sort();
    for (final k in keys) {
      // write partial row (missing sensors become empty fields)
      await _writeRowForTimestamp(k);
    }
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }
}
