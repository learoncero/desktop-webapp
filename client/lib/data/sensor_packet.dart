class SensorPacket {
  final DateTime timestamp;
  final Map<String, dynamic> values;

  SensorPacket({required this.timestamp, required this.values});
}
