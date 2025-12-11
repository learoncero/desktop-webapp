class SampledValue {
  final String dataStream;
  final String dataUnit;
  final DateTime timestamp;
  final double value;
  final int sampleCount; // How many raw values were averaged

  SampledValue({
    required this.dataStream,
    required this.dataUnit,
    required this.timestamp,
    required this.value,
    required this.sampleCount,
  });
}
