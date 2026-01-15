import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sensor_dash/models/sampled_value.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sensor_dash/services/csv_recorder.dart';
import 'package:sensor_dash/services/csv_loader.dart';
import 'package:sensor_dash/models/sensor_packet.dart';
import 'package:sensor_dash/services/sampling_manager.dart';

enum DataFormat { json, csv }

abstract class ConnectionBaseViewModel extends ChangeNotifier {
  bool _isConnected = false;
  bool _isRecording = false;
  String? _errorMessage;
  ReductionMethod _reductionMethod = ReductionMethod.average;

  SensorPacket? _lastPacket;
  String? _saveFolderPath;

  // CSV playback state
  CsvRecorder? _recorder;
  final CsvLoader _csvLoader = CsvLoader();
  bool _isCsvMode = false;
  String? _loadedCsvPath;

  // Packet broadcast stream
  final StreamController<SensorPacket> _packetController =
      StreamController<SensorPacket>.broadcast();

  // Sampling state
  String? _selectedSensorForPlot;
  String? _currentSensorUnit;
  List<String> _availableSensors = [];
  List<SampledValue>? _currentSamples;

  // Plot
  double _visibleStart = 0;
  double _visibleRange = 60;
  final Map<String, List<FlSpot>> _graphPoints = {};
  int _graphIndex = 0;
  bool _graphSliding = false;
  String _graphStartTime = "";

  // Statistics per data stream
  final Map<String, double> _minValues = {};
  final Map<String, double> _maxValues = {};
  final Map<String, double> _avgValues = {};
  final Map<String, String> _sensorUnits = {};

  // Data format setting - shared across all connection types
  static DataFormat _sharedDataFormat = DataFormat.json;

  // Getters
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  String? get errorMessage => _errorMessage;
  double get visibleStart => _visibleStart;
  double get visibleRange => _visibleRange;
  Map<String, List<FlSpot>> get graphPoints => _graphPoints;
  bool get graphSliding => _graphSliding;
  String get graphStartTime => _graphStartTime;
  ReductionMethod get reductionMethod => _reductionMethod;
  int get graphIndex => _graphIndex;
  SensorPacket? get lastPacket => _lastPacket;
  String? get saveFolderPath => _saveFolderPath;
  bool get isCsvMode => _isCsvMode;
  String? get loadedCsvPath => _loadedCsvPath;
  Stream<SensorPacket> get packetStream => _packetController.stream;
  String? get selectedSensorForPlot => _selectedSensorForPlot;
  String? get currentSensorUnit => _currentSensorUnit;
  List<String> get availableSensors => _availableSensors;
  List<SampledValue>? get currentSamples => _currentSamples;
  CsvRecorder? get recorder => _recorder;
  DataFormat get dataFormat => _sharedDataFormat;
  double get minValue => _selectedSensorForPlot != null
      ? _minValues[_selectedSensorForPlot] ?? double.infinity
      : double.infinity;
  double get maxValue => _selectedSensorForPlot != null
      ? _maxValues[_selectedSensorForPlot] ?? double.negativeInfinity
      : double.negativeInfinity;
  double get avgValue => _selectedSensorForPlot != null
      ? _avgValues[_selectedSensorForPlot] ?? 0
      : 0;

  // Setters
  @protected
  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  @protected
  void setRecording(bool value) {
    _isRecording = value;
  }

  @protected
  void setErrorMessage(String? value) {
    _errorMessage = value;
  }

  @protected
  void setLastPaket(SensorPacket packet) {
    _lastPacket = packet;
  }

  @protected
  void addPacketToPacketController(SensorPacket packet) {
    _packetController.add(packet);
  }

  @protected
  void setAvailableSensors(List<String> availableSensors) {
    _availableSensors = availableSensors;
  }

  @protected
  void setSelectedSensorForPlot(String? sensor) {
    _selectedSensorForPlot = sensor;
  }

  @protected
  void setCurrentSensorUnit(String sensorUnit) {
    _currentSensorUnit = sensorUnit;
  }

  @protected
  void setGraphStartTime(String graphStartTime) {
    _graphStartTime = graphStartTime;
  }

  @protected
  void addToGraphIndex(int num) {
    _graphIndex += num;
  }

  @protected
  void setCurrentSamples(List<SampledValue> samples) {
    _currentSamples = samples;
  }

  // Set the save folder path. If null, recording will stop.
  void setSaveFolderPath(String? path) {
    _saveFolderPath = path;
    notifyListeners();

    // Start/stop recorder depending on state
    maybeStartRecorder();
  }

  // Set the data format (JSON or CSV) - shared across all instances
  void setDataFormat(DataFormat format) {
    _sharedDataFormat = format;
    notifyListeners();
  }

  void startRecording() {
    if (!isConnected) return;

    // Reset graph for new recording session
    _resetGraphState();

    setRecording(true);
    maybeStartRecorder(); // Start CSV recording
    notifyListeners();
  }

  void stopRecording() {
    setRecording(false);
    _stopRecorder(); // Stop CSV recording
    notifyListeners();
  }

  void toggleRecording() {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  }

  void initDefaultSaveFolder() {
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

  void maybeStartRecorder() {
    // Stop existing if no folder, not connected, or not recording
    if (!isConnected || _saveFolderPath == null || !isRecording) {
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
          setErrorMessage(
            'Input sensors changed during recording: ${newSensors.join(', ')}',
          );
          notifyListeners();
        },
      );
      _recorder!.start();
    } catch (e) {
      setErrorMessage('Failed to start recorder: $e');
      notifyListeners();
    }
  }

  void _stopRecorder() {
    try {
      _recorder?.stop();
    } catch (_) {}
    _recorder = null;
  }

  /// Load and display a CSV file
  /// This will disconnect from serial (if connected) and enter CSV playback mode
  Future<String?> loadCsvFile(String filePath) async {
    try {
      if (isConnected) {
        disconnect();
      }

      // Reset state
      _resetGraphState();

      // Load CSV file
      final packets = await _csvLoader.loadCsvFile(filePath);

      if (packets.isEmpty) {
        setErrorMessage('CSV file contains no valid data');
        notifyListeners();
        return errorMessage;
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

      // Convert packets to graph points and calculate statistics
      for (final packet in packets) {
        for (final sensorData in packet.payload) {
          final dataStream = sensorData.displayName;
          final value = sensorData.data;

          _graphPoints.putIfAbsent(dataStream, () => []);
          _graphPoints[dataStream]!.add(FlSpot(_graphIndex.toDouble(), value));

          // Store unit for this data stream
          _sensorUnits[dataStream] = sensorData.displayUnit;

          // Update statistics for this data stream
          _minValues.putIfAbsent(dataStream, () => double.infinity);
          _maxValues.putIfAbsent(dataStream, () => double.negativeInfinity);
          _avgValues.putIfAbsent(dataStream, () => 0);

          if (value < _minValues[dataStream]!) {
            _minValues[dataStream] = value;
          }

          if (value > _maxValues[dataStream]!) {
            _maxValues[dataStream] = value;
          }

          // Calculate running average
          final currentAvg = _avgValues[dataStream]!;
          final count = _graphPoints[dataStream]!.length;
          _avgValues[dataStream] = ((currentAvg * (count - 1)) + value) / count;
        }
        _graphIndex += 1;
      }

      // Set the unit for the selected sensor after loading all data
      if (_selectedSensorForPlot != null) {
        _currentSensorUnit = _sensorUnits[_selectedSensorForPlot];
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
      setConnected(false);
      setRecording(false);
      setErrorMessage(null);

      notifyListeners();
      return null; // Success
    } catch (e) {
      setErrorMessage('Failed to load CSV file: $e');
      _isCsvMode = false;
      _loadedCsvPath = null;
      notifyListeners();
      return errorMessage;
    }
  }

  void disconnect() {
    setConnected(false);
    setRecording(false);
    _lastPacket = null;

    // Stop recorder if running
    _stopRecorder();

    _resetGraphState();

    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
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
    // _samplingManager?.dispose();
    disconnect();
    super.dispose();
  }

  // Plot
  void setVisibleRange(double range) {
    if (range < 10 || range > 300) return;
    _visibleRange = range;
    _visibleStart = (_graphIndex - _visibleRange).clamp(0, double.infinity);
    notifyListeners();
  }

  void setReductionMethod(ReductionMethod method) {
    _reductionMethod = method;
    notifyListeners();
  }

  void selectSensorForPlot(String sensorName) {
    if ((isCsvMode && _availableSensors.contains(sensorName)) ||
        (isConnected && _availableSensors.contains(sensorName))) {
      _selectedSensorForPlot = sensorName;
      _currentSensorUnit = _sensorUnits[sensorName];
      notifyListeners();
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

  void addSampleToGraph(String dataStream, double value, String unit) {
    if (!_isRecording) return; // Only plot when recording
    _graphPoints.putIfAbsent(dataStream, () => []);
    _graphPoints[dataStream]!.add(FlSpot(_graphIndex.toDouble(), value));

    // Store unit for this data stream
    _sensorUnits[dataStream] = unit;

    // Update statistics for this data stream
    _minValues.putIfAbsent(dataStream, () => double.infinity);
    _maxValues.putIfAbsent(dataStream, () => double.negativeInfinity);
    _avgValues.putIfAbsent(dataStream, () => 0);

    if (value < _minValues[dataStream]!) {
      _minValues[dataStream] = value;
    }

    if (value > _maxValues[dataStream]!) {
      _maxValues[dataStream] = value;
    }

    // Calculate running average
    final currentAvg = _avgValues[dataStream]!;
    final count = _graphPoints[dataStream]!.length;
    _avgValues[dataStream] = ((currentAvg * (count - 1)) + value) / count;

    // Update unit only for the selected sensor
    if (dataStream == _selectedSensorForPlot) {
      _currentSensorUnit = unit;
    }

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

  void _resetGraphState({bool resetVisibleRange = false}) {
    _graphPoints.clear();
    _graphIndex = 0;
    _visibleStart = 0;
    _graphStartTime = "";
    _graphSliding = false;
    _availableSensors = [];
    _selectedSensorForPlot = null;
    _currentSensorUnit = null;
    // Reset statistics
    _minValues.clear();
    _maxValues.clear();
    _avgValues.clear();
    _sensorUnits.clear();
    if (resetVisibleRange) {
      _visibleRange = 60;
    }
  }
}
