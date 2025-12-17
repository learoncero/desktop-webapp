class SampledValue {
  final String dataStream;
  final String dataUnit;
  final DateTime timestamp;
  final double value;

  SampledValue({
    required this.dataStream,
    required this.dataUnit,
    required this.timestamp,
    required this.value,
  });
}
