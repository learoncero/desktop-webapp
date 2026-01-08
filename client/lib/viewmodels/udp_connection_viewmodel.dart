import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:sensor_dash/services/sampling_manager.dart';
import 'package:sensor_dash/services/udp_source.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';

class UdpConnectionViewModel extends ConnectionBaseViewModel {
  final UdpSource Function(String address, int port) _udpFactory;

  final addressController = TextEditingController();
  final portController = TextEditingController();

  UdpConnectionViewModel({UdpSource Function(String, int)? serialFactory})
    : _udpFactory = serialFactory ?? ((p, b) => UdpSource(p, b)) {
    addressController.text = _address;
    portController.text = _port == 0 ? "" : _port.toString();

    // Initialize a cross-platform default save folder (user can still change it)
    initDefaultSaveFolder();
  }

  SamplingManager? _samplingManager;

  String _address = "";
  int _port = 0;
  UdpSource? _udp;

  String get address => _address;
  int get port => _port;

  Future<String?> connect() async {
    if (isConnected) {
      return null; // Already connected
    }

    try {
      _udp = _udpFactory(_address, _port);

      var success = _udp!.connect(
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
          setErrorMessage('Connection lost: Port disconnected.');
          disconnect();
        },
      );

      if (await success) {
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
              setCurrentSensorUnit(sample.dataUnit);

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
        _udp = null;
        setErrorMessage('Failed to open UDP connection');
        notifyListeners();
        return errorMessage;
      }
    } catch (e) {
      _udp = null;
      setErrorMessage('Connection error: $e');
      notifyListeners();
      return errorMessage;
    }
  }

  void updateAddress(String address) {
    _address = address.trim();
    notifyListeners();
  }

  void updatePort(String port) {
    final parsedPort = int.tryParse(port);
    if (parsedPort != null && parsedPort > 0) {
      _port = parsedPort;
    }
    notifyListeners();
  }

  @override
  void disconnect() {
    if (_samplingManager != null) {
      _samplingManager!.dispose();
    }

    _udp?.disconnect();
    _udp = null;
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
