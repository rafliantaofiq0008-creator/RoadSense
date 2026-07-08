class RoadPhoto {
  final String id;
  final String userId;
  final String sessionId;
  final String? eventId;
  final int? segmentIndex;
  final String storageBucket;
  final String storagePath;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final double? speed;
  final double? vibration;
  final String? caption;
  final String photoType;
  final DateTime takenAt;
  final DateTime createdAt;
  
  // Auxiliary property to hold signed URL for rendering
  String? signedUrl;

  RoadPhoto({
    required this.id,
    required this.userId,
    required this.sessionId,
    this.eventId,
    this.segmentIndex,
    this.storageBucket = 'road-photos',
    required this.storagePath,
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    this.speed,
    this.vibration,
    this.caption,
    this.photoType = 'manual',
    required this.takenAt,
    required this.createdAt,
    this.signedUrl,
  });

  factory RoadPhoto.fromMap(Map<String, dynamic> map) {
    return RoadPhoto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sessionId: map['session_id'] as String,
      eventId: map['event_id'] as String?,
      segmentIndex: map['segment_index'] as int?,
      storageBucket: map['storage_bucket'] as String? ?? 'road-photos',
      storagePath: map['storage_path'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      gpsAccuracy: (map['gps_accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      vibration: (map['vibration'] as num?)?.toDouble(),
      caption: map['caption'] as String?,
      photoType: map['photo_type'] as String? ?? 'manual',
      takenAt: DateTime.parse(map['taken_at'] as String).toLocal(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'event_id': eventId,
      'segment_index': segmentIndex,
      'storage_bucket': storageBucket,
      'storage_path': storagePath,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'speed': speed,
      'vibration': vibration,
      'caption': caption,
      'photo_type': photoType,
      'taken_at': takenAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  RoadPhoto copyWith({
    String? caption,
    String? signedUrl,
  }) {
    return RoadPhoto(
      id: id,
      userId: userId,
      sessionId: sessionId,
      eventId: eventId,
      segmentIndex: segmentIndex,
      storageBucket: storageBucket,
      storagePath: storagePath,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      speed: speed,
      vibration: vibration,
      caption: caption ?? this.caption,
      photoType: photoType,
      takenAt: takenAt,
      createdAt: createdAt,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }
}
