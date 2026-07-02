class RoadEvent {
  final String id;
  final String sessionId;
  final String userId;
  final String eventType;
  final String severity;
  final double magnitude;
  final double vibration;
  final double speed;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final DateTime recordedAt;

  const RoadEvent({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.eventType,
    required this.severity,
    required this.magnitude,
    required this.vibration,
    required this.speed,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.recordedAt,
  });

  RoadEvent copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? eventType,
    String? severity,
    double? magnitude,
    double? vibration,
    double? speed,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    DateTime? recordedAt,
  }) {
    return RoadEvent(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      severity: severity ?? this.severity,
      magnitude: magnitude ?? this.magnitude,
      vibration: vibration ?? this.vibration,
      speed: speed ?? this.speed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'event_type': eventType,
      'severity': severity,
      'magnitude': magnitude,
      'vibration': vibration,
      'speed': speed,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  factory RoadEvent.fromMap(Map<String, dynamic> map) {
    return RoadEvent(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      userId: map['user_id'] as String,
      eventType: map['event_type'] as String,
      severity: map['severity'] as String,
      magnitude: (map['magnitude'] as num).toDouble(),
      vibration: (map['vibration'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      gpsAccuracy: (map['gps_accuracy'] as num).toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
    );
  }
}
