import '../../core/utils/app_date_time.dart';

class RoadSession {
  final String id;
  final String userId;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final double? averageSpeed;
  final double? maxSpeed;
  final double? maxVibration;
  final double? estimatedDistanceKm;
  final int totalEvents;
  final DateTime createdAt;

  const RoadSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    this.endTime,
    this.averageSpeed,
    this.maxSpeed,
    this.maxVibration,
    this.estimatedDistanceKm,
    this.totalEvents = 0,
    required this.createdAt,
  });

  RoadSession copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    double? averageSpeed,
    double? maxSpeed,
    double? maxVibration,
    double? estimatedDistanceKm,
    int? totalEvents,
    DateTime? createdAt,
  }) {
    return RoadSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      maxVibration: maxVibration ?? this.maxVibration,
      estimatedDistanceKm: estimatedDistanceKm ?? this.estimatedDistanceKm,
      totalEvents: totalEvents ?? this.totalEvents,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'average_speed': averageSpeed,
      'max_speed': maxSpeed,
      'max_vibration': maxVibration,
      if (estimatedDistanceKm != null) 'estimated_distance_km': estimatedDistanceKm,
      'total_events': totalEvents,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory RoadSession.fromMap(Map<String, dynamic> map) {
    return RoadSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      startTime: AppDateTime.parseServer(map['start_time'] as String?),
      endTime: map['end_time'] != null ? AppDateTime.parseServer(map['end_time'] as String?) : null,
      averageSpeed: (map['average_speed'] as num?)?.toDouble(),
      maxSpeed: (map['max_speed'] as num?)?.toDouble(),
      maxVibration: (map['max_vibration'] as num?)?.toDouble(),
      estimatedDistanceKm: (map['estimated_distance_km'] as num?)?.toDouble(),
      totalEvents: map['total_events'] as int? ?? 0,
      createdAt: AppDateTime.parseServer(
        map['created_at'] as String?,
        fallback: DateTime.now(),
      ),
    );
  }
}
