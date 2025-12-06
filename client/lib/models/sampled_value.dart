class SampledValue {
  final DateTime timestamp;
  final double value;
  final int sampleCount; // How many raw values were averaged

  SampledValue({
    required this.timestamp,
    required this.value,
    required this.sampleCount,
  });
}
