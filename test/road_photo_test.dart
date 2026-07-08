import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/data/models/road_photo.dart';

void main() {
  group('RoadPhoto Tests', () {
    test('Constructor should properly assign fields', () {
      final now = DateTime.now();
      final photo = RoadPhoto(
        id: 'photo_123',
        userId: 'user_123',
        sessionId: 'session_123',
        storagePath: 'path/to/photo.jpg',
        takenAt: now,
        createdAt: now,
        caption: 'Test caption',
        latitude: -6.1,
        longitude: 106.8,
        gpsAccuracy: 10.0,
        speed: 40.5,
        vibration: 2.1,
      );

      expect(photo.id, 'photo_123');
      expect(photo.storageBucket, 'road-photos');
      expect(photo.caption, 'Test caption');
      expect(photo.latitude, -6.1);
    });

    test('toMap and fromMap should preserve data', () {
      final now = DateTime.now().toUtc();
      
      final map = {
        'id': 'photo_123',
        'user_id': 'user_123',
        'session_id': 'session_123',
        'event_id': null,
        'segment_index': null,
        'storage_bucket': 'road-photos',
        'storage_path': 'path/to/photo.jpg',
        'latitude': -6.1,
        'longitude': 106.8,
        'gps_accuracy': 10.0,
        'speed': 40.5,
        'vibration': 2.1,
        'caption': 'Test caption',
        'photo_type': 'manual',
        'taken_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final photo = RoadPhoto.fromMap(map);

      expect(photo.id, 'photo_123');
      expect(photo.caption, 'Test caption');
      
      final mappedBack = photo.toMap();
      expect(mappedBack['id'], 'photo_123');
      expect(mappedBack['caption'], 'Test caption');
    });
  });
}
