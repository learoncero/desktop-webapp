import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/services/sampling_manager.dart';
import 'dart:developer';
import 'dart:async';

import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';

class SerialConnectionViewModel extends ConnectionBaseViewModel {
  final SerialSource Function(String port, int baud, {bool simulate})
  _serialFactory;

  SerialConnectionViewModel({
    SerialSource Function(String, int, {bool simulate})? serialFactory,
  }) : _serialFactory =
           serialFactory ??
           ((p, b, {simulate = false}) =>
               SerialSource(p, b, simulate: simulate)) {
    // Initialize a cross-platform default save folder (user can still change it)
    initDefaultSaveFolder();
  }

  // Connection state
  String? _selectedPort = "COM1";
  int _selectedBaudrate = 115200;
  SerialSource? _serial;

  // Sampling state
  SamplingManager? _samplingManager;

  bool _isSimulated = false;

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
  bool get isSimulated => _isSimulated;

  // Setters with notification
  void selectPort(String? port) {
    if (isConnected) return;
    _selectedPort = port;
    notifyListeners();
  }

  void selectBaudrate(int baudrate) {
    if (isConnected) return;
    _selectedBaudrate = baudrate;
    notifyListeners();
  }

  Future<String?> connect({
    bool allowSimulationIfNoDevice = false,
    bool forceSimulate = false,
  }) async {
    if (_selectedPort == null) {
      setErrorMessage('Please select a port first');
      notifyListeners();
      return errorMessage;
    }

    if (isConnected) {
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
            setLastPaket(packet);
            setErrorMessage(null);
            try {
              addPacketToPacketController(packet);
            } catch (_) {}
            notifyListeners();
          },
          onError: (error) {
            setErrorMessage('Simulation error: $error');
            notifyListeners();
          },
        );

        if (simSuccess) {
          setConnected(true);
          setErrorMessage(null);
          notifyListeners();

          // Initialize sampling manager (samples every 1 second)
          _samplingManager = SamplingManager(
            onSampleReady: (samples) async {
              setCurrentSamples(samples);

              for (var sample in samples) {
                // Add sample to graph if recording
                addSampleToGraph(
                  sample.dataStream,
                  sample.value,
                  sample.dataUnit,
                );

                if (graphStartTime.isEmpty && isRecording) {
                  setGraphStartTime(
                    "${sample.timestamp.toLocal().day.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().year} "
                    "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}",
                  );
                }

                // Forward sample to recorder if recording
                try {
                  if (recorder != null && isRecording) {
                    await recorder!.recordSample(
                      sample.dataStream,
                      sample.dataUnit,
                      sample,
                    );
                  }
                } catch (e) {
                  // ignore recording errors for now
                }
              }

              if (recorder != null && isRecording) {
                addToGraphIndex(1);
              }
              notifyListeners();
            },
          );

          maybeStartRecorder();
          return null;
        } else {
          _serial = null;
          setErrorMessage('Failed to start simulation');
          notifyListeners();
          return errorMessage;
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
          setLastPaket(packet);
          setErrorMessage(null);

          // Add to packet stream for any listeners (e.g., recorder)
          try {
            addPacketToPacketController(packet);
          } catch (_) {}

          final sensorNames = packet.payload.map((s) => s.displayName).toList();

          if (availableSensors.isEmpty) {
            // First time: initialize sensors
            setAvailableSensors(sensorNames);
            if (selectedSensorForPlot == null && sensorNames.isNotEmpty) {
              setSelectedSensorForPlot(sensorNames.first);
            }
          } else {
            // Check if sensors have changed
            final currentSet = availableSensors.toSet();
            final newSet = sensorNames.toSet();

            if (currentSet != newSet) {
              if (!isRecording) {
                // Update sensors if not recording
                setAvailableSensors(sensorNames);

                // If selected sensor is no longer available, reset to first available
                if (selectedSensorForPlot != null &&
                    !sensorNames.contains(selectedSensorForPlot)) {
                  setSelectedSensorForPlot(
                    sensorNames.isNotEmpty ? sensorNames.first : null,
                  );
                }
              } else {
                // Show warning if recording and sensors changed
                setErrorMessage(
                  'Sensors changed during recording. Please stop recording to update.',
                );
              }
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
          setErrorMessage('Connection lost: Port $_selectedPort disconnected.');
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
            setLastPaket(packet);
            setErrorMessage(null);
            try {
              addPacketToPacketController(packet);
            } catch (_) {}
            notifyListeners();
          },
          onError: (error) {
            setErrorMessage('Simulation error: $error');
            notifyListeners();
          },
        );
      }

      if (success) {
        setConnected(true);
        setErrorMessage(null);

        // Initialize sampling manager (samples every 1 second)
        _samplingManager = SamplingManager(
          reductionMethod: reductionMethod,
          onSampleReady: (samples) async {
            setCurrentSamples(samples);

            for (var sample in samples) {
              // Only add the selected sensor to the graph
              addSampleToGraph(
                sample.dataStream,
                sample.value,
                sample.dataUnit,
              );

              if (graphStartTime.isEmpty && isRecording) {
                setGraphStartTime(
                  "${sample.timestamp.toLocal().day.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().year} "
                  "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}",
                );
              }

              // Forward sample to recorder if recording
              try {
                if (recorder != null && isRecording) {
                  // If recorder sensors aren't locked yet, lock them on first batch
                  if (!recorder!.sensorsLocked) {
                    final initial = samples.map((s) => s.dataStream).toList();
                    recorder!.setInitialSensors(initial);
                  }

                  await recorder!.recordSample(
                    sample.dataStream,
                    sample.dataUnit,
                    sample,
                  );
                }
              } catch (e) {
                // ignore recording errors for now
              }
            }

            if (recorder != null && isRecording) {
              addToGraphIndex(1);
            }
            notifyListeners();
          },
        );

        // Maybe start recorder if folder set
        maybeStartRecorder();

        return null; // Success
      } else {
        _serial = null;
        setErrorMessage('Failed to open serial port: $_selectedPort');
        notifyListeners();
        return errorMessage;
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
            setLastPaket(packet);
            setErrorMessage(null);
            try {
              addPacketToPacketController(packet);
            } catch (_) {}
            notifyListeners();
          },
          onError: (error) {
            setErrorMessage('Simulation error: $error');
            notifyListeners();
          },
        );
        if (simSuccess) {
          setConnected(true);
          setErrorMessage(null);
          notifyListeners();

          // Initialize sampling manager (samples every 1 second)
          _samplingManager = SamplingManager(
            reductionMethod: reductionMethod,
            onSampleReady: (samples) async {
              setCurrentSamples(samples);

              for (var sample in samples) {
                // Only add the selected sensor to the graph
                addSampleToGraph(
                  sample.dataStream,
                  sample.value,
                  sample.dataUnit,
                );

                try {
                  if (recorder != null && isRecording) {
                    await recorder!.recordSample(
                      sample.dataStream,
                      sample.dataUnit,
                      sample,
                    );
                  }
                } catch (e) {
                  // ignore recording errors for now
                }
              }

              if (recorder != null && isRecording) {
                addToGraphIndex(1);
              }
              notifyListeners();
            },
          );

          maybeStartRecorder();
          return null;
        }
      }

      _serial = null;
      _isSimulated = false;
      setErrorMessage('Connection error: $e');
      notifyListeners();
      return errorMessage;
    }
  }

  // Disconnect from Data Source
  @override
  void disconnect() {
    if (_samplingManager != null) {
      _samplingManager!.dispose();
    }

    _serial?.disconnect();
    _serial = null;
    _samplingManager = null;

    super.disconnect();
    notifyListeners();
  }

  @override
  void setReductionMethod(ReductionMethod method) {
    super.setReductionMethod(method);
    _samplingManager?.reductionMethod = method;
  }
}
