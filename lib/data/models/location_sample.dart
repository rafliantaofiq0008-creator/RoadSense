class LocationSample {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedMetersPerSecond;
  final double speedKmh;
  final double accuracy;
  final double? altitude;
  final double? heading;

  const LocationSample({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedMetersPerSecond,
    required this.speedKmh,
    required this.accuracy,
    this.altitude,
    this.heading,
  });

  LocationSample copyWith({
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? speedMetersPerSecond,
    double? speedKmh,
    double? accuracy,
    double? altitude,
    double? heading,
  }) {
    return LocationSample(
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedMetersPerSecond: speedMetersPerSecond ?? this.speedMetersPerSecond,
      speedKmh: speedKmh ?? this.speedKmh,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'speedMetersPerSecond': speedMetersPerSecond,
      'speedKmh': speedKmh,
      'accuracy': accuracy,
      'altitude': altitude,
      'heading': heading,
    };
  }

  factory LocationSample.fromMap(Map<String, dynamic> map) {
    return LocationSample(
      timestamp: DateTime.parse(map['timestamp']),
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      speedMetersPerSecond: map['speedMetersPerSecond'] as double,
      speedKmh: map['speedKmh'] as double,
      accuracy: map['accuracy'] as double,
      altitude: map['altitude'] as double?,
      heading: map['heading'] as double?,
    );
  }
}
