class SensorData {
  final String displayName;
  final String displayUnit;
  final double data;

  SensorData({
    required this.displayName,
    required this.displayUnit,
    required this.data,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      displayName: json['displayName'] as String,
      displayUnit: json['displayUnit'] as String,
      data: (json['data'] as num).toDouble(),
    );
  }
}

class SensorPacket {
  final DateTime timestamp;
  final List<SensorData> payload;

  SensorPacket({
    required this.timestamp,
    required this.payload,
  });
}
