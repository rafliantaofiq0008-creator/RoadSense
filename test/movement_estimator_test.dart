import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/services/movement_estimator.dart';
import 'package:roadsense/data/models/location_sample.dart';

void main() {
  group('MovementEstimator Tests', () {
    late MovementEstimator estimator;

    setUp(() {
      estimator = MovementEstimator();
    });

    test('Initial processing returns same location', () {
      final sample = LocationSample(
        latitude: -6.200000,
        longitude: 106.816666,
        accuracy: 10.0,
        speedMetersPerSecond: 10.0 / 3.6,
        speedKmh: 10.0,
        altitude: 0,
        heading: 0,
        timestamp: DateTime.now(),
      );

      final result = estimator.processLocation(sample);
      expect(result.speedKmh, 10.0);
      expect(estimator.totalDistanceM, 0.0);
    });

    test('Rejects stationary jitter', () {
      final now = DateTime.now();
      final sample1 = LocationSample(
        latitude: -6.200000,
        longitude: 106.816666,
        accuracy: 15.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now,
      );

      // Moved very slightly (less than GPS accuracy 15m) and speed is 0
      final sample2 = LocationSample(
        latitude: -6.200005,
        longitude: 106.816670,
        accuracy: 15.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now.add(const Duration(seconds: 1)),
      );

      estimator.processLocation(sample1);
      estimator.processLocation(sample2);

      // Should not accumulate distance
      expect(estimator.totalDistanceM, 0.0);
    });

    test('Accumulates valid movement', () {
      final now = DateTime.now();
      final sample1 = LocationSample(
        latitude: -6.200000,
        longitude: 106.816666,
        accuracy: 5.0,
        speedMetersPerSecond: 10.0,
        speedKmh: 36.0, // 10 m/s
        altitude: 0,
        heading: 0,
        timestamp: now,
      );

      // Moved ~11 meters North
      final sample2 = LocationSample(
        latitude: -6.199900,
        longitude: 106.816666,
        accuracy: 5.0,
        speedMetersPerSecond: 10.0,
        speedKmh: 36.0, // 10 m/s
        altitude: 0,
        heading: 0,
        timestamp: now.add(const Duration(seconds: 1)),
      );

      estimator.processLocation(sample1);
      estimator.processLocation(sample2);

      // Should accumulate distance
      expect(estimator.totalDistanceM, greaterThan(10.0));
    });
  });
}
