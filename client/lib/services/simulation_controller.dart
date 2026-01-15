import 'package:sensor_dash/services/serial_source.dart';
import 'package:sensor_dash/services/sampling_manager.dart';
import 'package:sensor_dash/models/sensor_packet.dart';
import 'package:sensor_dash/models/sampled_value.dart';
import 'package:sensor_dash/services/csv_recorder.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';

/// Full simulation controller that encapsulates SimulationConnection-like
/// behavior and also implements the sample-routing / recorder / graph logic.
class SimulationController {
  final SerialSource Function(String, int, {bool simulate, DataFormat dataFormat})
      serialFactory;
  final String port;
  final int baud;
  final DataFormat dataFormat;
  final ReductionMethod reductionMethod;

  SerialSource? _source;
  SamplingManager? _samplingManager;

  SimulationController({
    required this.serialFactory,
    required this.port,
    required this.baud,
    this.reductionMethod = ReductionMethod.average,
    this.dataFormat = DataFormat.json,
  });

  SerialSource? get source => _source;
  SamplingManager? get samplingManager => _samplingManager;
  bool get isSimulated => _source?.simulate ?? true;

  bool connect({
    required void Function(SensorPacket) setLastPaket,
    required void Function(String? value) setErrorMessage,
    required void Function(SensorPacket) addPacketToPacketController,
    required void Function(List<SampledValue>) setCurrentSamples,
    required void Function(String dataStream, double value, String unit)
        addSampleToGraph,
    required String Function() getGraphStartTime,
    required bool Function() isRecording,
    required void Function(String) setGraphStartTime,
    required CsvRecorder? Function() getRecorder,
    required void Function(int) addToGraphIndex,
    required void Function() notifyListeners,
  }) {
    _source = serialFactory(port, baud, simulate: true, dataFormat: dataFormat);

    final success = _source!.connect(
      onPacket: (packet) {
        setLastPaket(packet);
        setErrorMessage(null);
        try {
          addPacketToPacketController(packet);
        } catch (_) {}
        notifyListeners();
      },
      onError: (err) {
        setErrorMessage('Simulation error: $err');
        notifyListeners();
      },
    );

    if (!success) {
      _source = null;
      return false;
    }

    _samplingManager = SamplingManager(
      reductionMethod: reductionMethod,
      onSampleReady: (samples) async {
        setCurrentSamples(samples);

        for (var sample in samples) {
          // add sample to graph
          addSampleToGraph(
            sample.dataStream,
            sample.value,
            sample.dataUnit,
          );

          if (getGraphStartTime().isEmpty && isRecording()) {
            setGraphStartTime(
              "${sample.timestamp.toLocal().day.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().month.toString().padLeft(2, '0')}.${sample.timestamp.toLocal().year} "
              "${sample.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${sample.timestamp.toLocal().second.toString().padLeft(2, '0')}",
            );
          }

          // recorder
          try {
            final rec = getRecorder();
            if (rec != null && isRecording()) {
              if (!rec.sensorsLocked) {
                final initial = samples.map((s) => s.dataStream).toList();
                rec.setInitialSensors(initial);
              }

              await rec.recordSample(
                sample.dataStream,
                sample.dataUnit,
                sample,
              );
            }
          } catch (_) {}
        }

        if (getRecorder() != null && isRecording()) {
          addToGraphIndex(1);
        }

        notifyListeners();
      },
    );

    return true;
  }

  void dispose() {
    try {
      _samplingManager?.dispose();
    } catch (_) {}
    _samplingManager = null;

    try {
      _source?.disconnect();
    } catch (_) {}
    _source = null;
  }
}
