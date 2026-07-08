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
  
  // Accuracy diagnostic fields
  final int? confidenceScore;
  final double? verticalPeak;
  final double? lateralPeak;
  final double? jerkPeak;
  final double? gyroMagnitude;
  final double? headingChangeRate;
  final String? validationStatus;
  final String? rejectionReason;

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
    this.confidenceScore,
    this.verticalPeak,
    this.lateralPeak,
    this.jerkPeak,
    this.gyroMagnitude,
    this.headingChangeRate,
    this.validationStatus,
    this.rejectionReason,
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
    int? confidenceScore,
    double? verticalPeak,
    double? lateralPeak,
    double? jerkPeak,
    double? gyroMagnitude,
    double? headingChangeRate,
    String? validationStatus,
    String? rejectionReason,
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
      confidenceScore: confidenceScore ?? this.confidenceScore,
      verticalPeak: verticalPeak ?? this.verticalPeak,
      lateralPeak: lateralPeak ?? this.lateralPeak,
      jerkPeak: jerkPeak ?? this.jerkPeak,
      gyroMagnitude: gyroMagnitude ?? this.gyroMagnitude,
      headingChangeRate: headingChangeRate ?? this.headingChangeRate,
      validationStatus: validationStatus ?? this.validationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
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
      'confidence_score': confidenceScore,
      'vertical_peak': verticalPeak,
      'lateral_peak': lateralPeak,
      'jerk_peak': jerkPeak,
      'gyro_magnitude': gyroMagnitude,
      'heading_change_rate': headingChangeRate,
      'validation_status': validationStatus,
      'rejection_reason': rejectionReason,
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
      confidenceScore: map['confidence_score'] as int?,
      verticalPeak: (map['vertical_peak'] as num?)?.toDouble(),
      lateralPeak: (map['lateral_peak'] as num?)?.toDouble(),
      jerkPeak: (map['jerk_peak'] as num?)?.toDouble(),
      gyroMagnitude: (map['gyro_magnitude'] as num?)?.toDouble(),
      headingChangeRate: (map['heading_change_rate'] as num?)?.toDouble(),
      validationStatus: map['validation_status'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}
