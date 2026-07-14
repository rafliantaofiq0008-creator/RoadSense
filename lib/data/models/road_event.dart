import '../../core/utils/app_date_time.dart';

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
  
  // Accuracy diagnostic fields
  final int? confidenceScore;
  final double? verticalPeak;
  final double? lateralPeak;
  final double? jerkPeak;
  final double? gyroMagnitude;
  final double? headingChangeRate;
  final double? speedAtEvent;
  final String? validationStatus;
  final String? rejectionReason;
  final String? vehicleProfileId;

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
    this.confidenceScore,
    this.verticalPeak,
    this.lateralPeak,
    this.jerkPeak,
    this.gyroMagnitude,
    this.headingChangeRate,
    this.speedAtEvent,
    this.validationStatus,
    this.rejectionReason,
    this.vehicleProfileId,
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
    int? confidenceScore,
    double? verticalPeak,
    double? lateralPeak,
    double? jerkPeak,
    double? gyroMagnitude,
    double? headingChangeRate,
    double? speedAtEvent,
    String? validationStatus,
    String? rejectionReason,
    String? vehicleProfileId,
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
      confidenceScore: confidenceScore ?? this.confidenceScore,
      verticalPeak: verticalPeak ?? this.verticalPeak,
      lateralPeak: lateralPeak ?? this.lateralPeak,
      jerkPeak: jerkPeak ?? this.jerkPeak,
      gyroMagnitude: gyroMagnitude ?? this.gyroMagnitude,
      headingChangeRate: headingChangeRate ?? this.headingChangeRate,
      speedAtEvent: speedAtEvent ?? this.speedAtEvent,
      validationStatus: validationStatus ?? this.validationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      vehicleProfileId: vehicleProfileId ?? this.vehicleProfileId,
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
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (verticalPeak != null) 'vertical_peak': verticalPeak,
      if (lateralPeak != null) 'lateral_peak': lateralPeak,
      if (jerkPeak != null) 'jerk_peak': jerkPeak,
      if (gyroMagnitude != null) 'gyro_magnitude': gyroMagnitude,
      if (headingChangeRate != null) 'heading_change_rate': headingChangeRate,
      if (speedAtEvent != null) 'speed_at_event': speedAtEvent,
      if (validationStatus != null) 'validation_status': validationStatus,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (vehicleProfileId != null) 'vehicle_profile_id': vehicleProfileId,
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
      recordedAt: AppDateTime.parseServer(map['recorded_at'] as String?),
      confidenceScore: map['confidence_score'] as int?,
      verticalPeak: (map['vertical_peak'] as num?)?.toDouble(),
      lateralPeak: (map['lateral_peak'] as num?)?.toDouble(),
      jerkPeak: (map['jerk_peak'] as num?)?.toDouble(),
      gyroMagnitude: (map['gyro_magnitude'] as num?)?.toDouble(),
      headingChangeRate: (map['heading_change_rate'] as num?)?.toDouble(),
      speedAtEvent: (map['speed_at_event'] as num?)?.toDouble(),
      validationStatus: map['validation_status'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
      vehicleProfileId: map['vehicle_profile_id'] as String?,
    );
  }
}
