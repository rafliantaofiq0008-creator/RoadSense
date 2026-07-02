class RoadReading {
  final String id;
  final String sessionId;
  final String userId;
  final double accelerationX;
  final double accelerationY;
  final double accelerationZ;
  final double magnitude;
  final double vibration;
  final double speed;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final DateTime recordedAt;

  const RoadReading({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.accelerationX,
    required this.accelerationY,
    required this.accelerationZ,
    required this.magnitude,
    required this.vibration,
    required this.speed,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.recordedAt,
  });

  RoadReading copyWith({
    String? id,
    String? sessionId,
    String? userId,
    double? accelerationX,
    double? accelerationY,
    double? accelerationZ,
    double? magnitude,
    double? vibration,
    double? speed,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    DateTime? recordedAt,
  }) {
    return RoadReading(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      accelerationX: accelerationX ?? this.accelerationX,
      accelerationY: accelerationY ?? this.accelerationY,
      accelerationZ: accelerationZ ?? this.accelerationZ,
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
      'acceleration_x': accelerationX,
      'acceleration_y': accelerationY,
      'acceleration_z': accelerationZ,
      'magnitude': magnitude,
      'vibration': vibration,
      'speed': speed,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  factory RoadReading.fromMap(Map<String, dynamic> map) {
    return RoadReading(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      userId: map['user_id'] as String,
      accelerationX: (map['acceleration_x'] as num).toDouble(),
      accelerationY: (map['acceleration_y'] as num).toDouble(),
      accelerationZ: (map['acceleration_z'] as num).toDouble(),
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
