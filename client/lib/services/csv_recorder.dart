import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sensor_data_app/models/sampled_value.dart';

class CsvRecorder {
  final String folderPath;
  final String baseFileName;

  final List<String> sensors; // Optional initial list of expected sensor names (human readable)
  late List<String> _sensorKeys; // Normalized sensor keys used for mapping incoming samples to CSV columns.

  bool _sensorsLocked = false; // Whether the sensor list has been locked (header written and will not change for the rest of this CSV file). When locked, new sensor names will trigger the onSensorsChanged callback instead of expanding the CSV columns.
  bool _headerWritten = false;

  final void Function(List<String> newSensors)? onSensorsChanged; // Optional callback invoked when a new sensor is observed after sensors are locked.

  IOSink? _sink;
  File? _file;
  bool _started = false;

  final Map<int, Map<String, Map<String, String>>> _pending = {};
  final Set<int> _writtenTimestamps = {}; // Track timestamps already written to avoid duplicate rows when late sensors appear.

  CsvRecorder({required this.folderPath, String? baseFileName, List<String>? sensors, this.onSensorsChanged})
      : baseFileName = baseFileName ?? 'sensor_record',
        sensors = sensors ?? const [] {
    // Use a (possibly empty) initial sensors list. If non-empty, lock it.
    _sensorKeys = this.sensors
        .map((s) => s.trim().toLowerCase().replaceAll(RegExp(r"\s+"), ''))
        .toList();
    if (_sensorKeys.isNotEmpty) {
      _sensorsLocked = true;
    }
  }

  bool get sensorsLocked => _sensorsLocked; // Returns whether the recorder has already locked the initial sensor set.

  /// Lock the initial sensors (called by the caller when the first sample batch
  /// is known). If already locked, this is a no-op. The provided list will be
  /// normalized and used to write the header if the file/sink is already open.
  void setInitialSensors(List<String> initialSensors) {
    if (_sensorsLocked) return;
    _sensorKeys = initialSensors
        .map((s) => s.trim().toLowerCase().replaceAll(RegExp(r"\s+"), ''))
        .toList();
    _sensorsLocked = true;

    // If the sink is open but header not written yet, write it now.
    if (_sink != null && !_headerWritten) {
      _writeHeader();
      _headerWritten = true;
    }
  }

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
    _writtenTimestamps.clear();
    _headerWritten = false;
    _sensorsLocked = false;
  }

  /// Record a prepared sample into the CSV. This method is safe to call even
  /// if the recorder hasn't been started; it will try to create the folder
  /// on demand.
  ///
  /// Important:
  /// - If a new sensor is observed after the sensor set was locked, the
  ///   recorder will invoke the optional `onSensorsChanged` callback and will
  ///   continue writing CSV rows using the initial columns only.
  Future<void> recordSample(
    String sensorName,
    String unit,
    SampledValue sample,
  ) async {
    if (!_started) {
      await start();
    }

    await _ensureFileOpen(sample.timestamp);

    final unix = sample.timestamp.millisecondsSinceEpoch ~/ 1000;
    final key = _normalizeSensorName(sensorName);

    // If sensors are locked and this key is unknown -> notify about change and do not add it to CSV columns.
    if (_sensorsLocked && !_sensorKeys.contains(key)) {
      try {
        onSensorsChanged?.call([sensorName]);
      } catch (_) {}
      // If a row for this timestamp is already written, don't add a new pending entry
      if (_writtenTimestamps.contains(unix)) {
        return;
      }
      // Still collect the sample in pending so that a later call to _flushRemaining will not lose it entirely, but won't include it in CSV columns.
      _pending.putIfAbsent(unix, () => {});
      _pending[unix]![key] = {
        'unit': unit,
        'value': sample.value.toString(),
      };
      return;
    }

    // If a row for this timestamp is already written, ignore further samples for it
    if (_writtenTimestamps.contains(unix)) {
      return;
    }

    _pending.putIfAbsent(unix, () => {});
    _pending[unix]![key] = {
      'unit': unit,
      'value': sample.value.toString(),
    };

    /// If sensors are locked, we know how many columns to expect for a complete
    /// row and can write it when all are present. If sensors are not yet locked
    /// we won't attempt to write rows here - the caller is expected to lock the
    /// sensor set first (see setInitialSensors).
    if (_sensorsLocked && _pending[unix]!.length == _sensorKeys.length) {
      await _writeRowForTimestamp(unix);
    }
  }

  Future<void> _ensureFileOpen(DateTime now) async {
    if (_sink != null) return;

    final timestamp = _formatDate(now);
    final filename = '${baseFileName}_$timestamp.csv';
    _file = File(p.join(folderPath, filename));
    _sink = _file!.openWrite(mode: FileMode.write);

    // Write UTF-8 BOM
    try {
      _sink!.write('\uFEFF');
    } catch (_) {}

    /// Write header immediately only if sensors are already locked; otherwise
    /// header will be written later from setInitialSensors when initial sensors
    /// are provided.
    if (_sensorsLocked && !_headerWritten) {
      _writeHeader();
      _headerWritten = true;
    }
  }

  void _writeHeader() {
    if (_sink == null) return;
    final parts = <String>[];
    parts.add('timestamp');
    for (final s in _sensorKeys) {
      parts.add('${s}_unit');
      parts.add('${s}_value');
    }
    _sink!.writeln(parts.join(','));
  }

  Future<void> _writeRowForTimestamp(int unix) async {
    final rowMap = _pending[unix];
    if (rowMap == null) return;

    // If the rowMap does not contain any of the known/initial sensor keys, then this timestamp only has unknown sensors -> skip writing an empty row.
    final hasKnownSensorValue = _sensorKeys.any((s) => rowMap.containsKey(s));
    if (!hasKnownSensorValue) {
      _pending.remove(unix);
      return;
    }

    final values = <String>[];
    values.add(unix.toString());
    for (final s in _sensorKeys) {
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
    _writtenTimestamps.add(unix);
  }

  String _escapeForCsv(String v) => '"${v.replaceAll('"', '""')}"';

  Future<void> _flushRemaining() async {
    if (_pending.isEmpty) return;
    final keys = _pending.keys.toList()..sort();

    /// If header hasn't been written but sensors have been locked (possible when
    /// setInitialSensors was called after file open), ensure header is written
    /// before flushing rows.
    if (_sensorsLocked && !_headerWritten) {
      _writeHeader();
      _headerWritten = true;
    }

    for (final k in keys) {
      // Skip timestamps already written to avoid duplicate lines
      if (_writtenTimestamps.contains(k)) continue;
      await _writeRowForTimestamp(k);
    }
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }

  String _normalizeSensorName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r"\s+"), '');
  }
}
