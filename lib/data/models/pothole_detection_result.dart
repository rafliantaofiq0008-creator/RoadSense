class PotholeDetectionResult {
  final DateTime timestamp;
  final String eventType;
  final String severity;
  final double magnitude;
  final double vibration;
  final double speed;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String? reason;

  const PotholeDetectionResult({
    required this.timestamp,
    required this.eventType,
    required this.severity,
    required this.magnitude,
    required this.vibration,
    required this.speed,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    this.reason,
  });

  PotholeDetectionResult copyWith({
    DateTime? timestamp,
    String? eventType,
    String? severity,
    double? magnitude,
    double? vibration,
    double? speed,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? reason,
  }) {
    return PotholeDetectionResult(
      timestamp: timestamp ?? this.timestamp,
      eventType: eventType ?? this.eventType,
      severity: severity ?? this.severity,
      magnitude: magnitude ?? this.magnitude,
      vibration: vibration ?? this.vibration,
      speed: speed ?? this.speed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'event_type': eventType,
      'severity': severity,
      'magnitude': magnitude,
      'vibration': vibration,
      'speed': speed,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'reason': reason,
    };
  }

  factory PotholeDetectionResult.fromMap(Map<String, dynamic> map) {
    return PotholeDetectionResult(
      timestamp: DateTime.parse(map['timestamp'] as String),
      eventType: map['event_type'] as String,
      severity: map['severity'] as String,
      magnitude: (map['magnitude'] as num).toDouble(),
      vibration: (map['vibration'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      gpsAccuracy: (map['gps_accuracy'] as num).toDouble(),
      reason: map['reason'] as String?,
    );
  }
}
