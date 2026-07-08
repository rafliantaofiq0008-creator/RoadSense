class RoadSegmentAnalysis {
  final String? id;
  final String userId;
  final String sessionId;
  final int segmentIndex;
  final double distanceStartM;
  final double distanceEndM;
  final double segmentLengthM;
  final int readingsCount;
  final double? avgSpeedKmh;
  final double? maxSpeedKmh;
  final double? avgVibration;
  final double? maxVibration;
  final double? verticalPeak;
  final double? jerkPeak;
  final double? lateralPeak;
  final double? gpsAccuracyAvg;
  final int eventCount;
  final int potholeCount;
  final int severePotholeCount;
  final int speedBumpCount;
  final String dataConfidenceLevel;
  final String roadCondition;
  final double? conditionScore;
  final String? recommendation;
  final DateTime? createdAt;

  const RoadSegmentAnalysis({
    this.id,
    required this.userId,
    required this.sessionId,
    required this.segmentIndex,
    required this.distanceStartM,
    required this.distanceEndM,
    required this.segmentLengthM,
    this.readingsCount = 0,
    this.avgSpeedKmh,
    this.maxSpeedKmh,
    this.avgVibration,
    this.maxVibration,
    this.verticalPeak,
    this.jerkPeak,
    this.lateralPeak,
    this.gpsAccuracyAvg,
    this.eventCount = 0,
    this.potholeCount = 0,
    this.severePotholeCount = 0,
    this.speedBumpCount = 0,
    this.dataConfidenceLevel = 'low',
    this.roadCondition = 'not_assessed',
    this.conditionScore,
    this.recommendation,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'segment_index': segmentIndex,
      'distance_start_m': distanceStartM,
      'distance_end_m': distanceEndM,
      'segment_length_m': segmentLengthM,
      'readings_count': readingsCount,
      'avg_speed_kmh': avgSpeedKmh,
      'max_speed_kmh': maxSpeedKmh,
      'avg_vibration': avgVibration,
      'max_vibration': maxVibration,
      'vertical_peak': verticalPeak,
      'jerk_peak': jerkPeak,
      'lateral_peak': lateralPeak,
      'gps_accuracy_avg': gpsAccuracyAvg,
      'event_count': eventCount,
      'pothole_count': potholeCount,
      'severe_pothole_count': severePotholeCount,
      'speed_bump_count': speedBumpCount,
      'data_confidence_level': dataConfidenceLevel,
      'road_condition': roadCondition,
      'condition_score': conditionScore,
      'recommendation': recommendation,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  factory RoadSegmentAnalysis.fromMap(Map<String, dynamic> map) {
    return RoadSegmentAnalysis(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      sessionId: map['session_id'] as String,
      segmentIndex: map['segment_index'] as int,
      distanceStartM: (map['distance_start_m'] as num).toDouble(),
      distanceEndM: (map['distance_end_m'] as num).toDouble(),
      segmentLengthM: (map['segment_length_m'] as num).toDouble(),
      readingsCount: map['readings_count'] as int? ?? 0,
      avgSpeedKmh: (map['avg_speed_kmh'] as num?)?.toDouble(),
      maxSpeedKmh: (map['max_speed_kmh'] as num?)?.toDouble(),
      avgVibration: (map['avg_vibration'] as num?)?.toDouble(),
      maxVibration: (map['max_vibration'] as num?)?.toDouble(),
      verticalPeak: (map['vertical_peak'] as num?)?.toDouble(),
      jerkPeak: (map['jerk_peak'] as num?)?.toDouble(),
      lateralPeak: (map['lateral_peak'] as num?)?.toDouble(),
      gpsAccuracyAvg: (map['gps_accuracy_avg'] as num?)?.toDouble(),
      eventCount: map['event_count'] as int? ?? 0,
      potholeCount: map['pothole_count'] as int? ?? 0,
      severePotholeCount: map['severe_pothole_count'] as int? ?? 0,
      speedBumpCount: map['speed_bump_count'] as int? ?? 0,
      dataConfidenceLevel: map['data_confidence_level'] as String? ?? 'low',
      roadCondition: map['road_condition'] as String? ?? 'not_assessed',
      conditionScore: (map['condition_score'] as num?)?.toDouble(),
      recommendation: map['recommendation'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String).toLocal() : null,
    );
  }
}
