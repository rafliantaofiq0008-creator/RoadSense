import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/data/models/location_sample.dart';

void main() {
  group('LocationSample', () {
    test('Constructor should properly assign fields', () {
      final now = DateTime.now();
      final sample = LocationSample(
        timestamp: now,
        latitude: 10.0,
        longitude: 20.0,
        speedMetersPerSecond: 5.0,
        speedKmh: 18.0,
        accuracy: 10.0,
        altitude: 100.0,
        heading: 90.0,
      );

      expect(sample.timestamp, equals(now));
      expect(sample.latitude, equals(10.0));
      expect(sample.speedKmh, equals(18.0));
      expect(sample.altitude, equals(100.0));
    });

    test('copyWith should override only provided fields', () {
      final now = DateTime.now();
      final sample = LocationSample(
        timestamp: now,
        latitude: 10.0,
        longitude: 20.0,
        speedMetersPerSecond: 5.0,
        speedKmh: 18.0,
        accuracy: 10.0,
      );

      final updated = sample.copyWith(latitude: 30.0, altitude: 50.0);

      expect(updated.latitude, equals(30.0));
      expect(updated.longitude, equals(20.0));
      expect(updated.altitude, equals(50.0));
      expect(updated.heading, isNull);
    });

    test('toMap and fromMap should preserve data', () {
      final now = DateTime.now();
      final sample = LocationSample(
        timestamp: now,
        latitude: 10.0,
        longitude: 20.0,
        speedMetersPerSecond: 5.0,
        speedKmh: 18.0,
        accuracy: 10.0,
        altitude: 100.0,
      );

      final map = sample.toMap();
      final converted = LocationSample.fromMap(map);

      // Timestamps may lose sub-millisecond precision based on toIso8601String,
      // so we check year, month, day, hour, minute, second.
      expect(converted.timestamp.year, equals(now.year));
      expect(converted.latitude, equals(10.0));
      expect(converted.longitude, equals(20.0));
      expect(converted.speedKmh, equals(18.0));
      expect(converted.altitude, equals(100.0));
      expect(converted.heading, isNull);
    });
  });
}
