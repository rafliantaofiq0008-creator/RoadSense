import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/config/tracking_sensitivity.dart';
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

      // Moved very slightly (less than 0.5m) and speed is 0
      final sample2 = LocationSample(
        latitude: -6.200001,
        longitude: 106.816667,
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

    test('Falls back to coordinate-based speed when timestamp does not advance', () {
      final now = DateTime.now();
      final sample1 = LocationSample(
        latitude: -6.200000,
        longitude: 106.816666,
        accuracy: 5.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now,
      );

      // Moved ~11 meters, but provider still reports the same timestamp and zero speed.
      final sample2 = LocationSample(
        latitude: -6.199900,
        longitude: 106.816666,
        accuracy: 5.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now,
      );

      estimator.processLocation(sample1);
      final result = estimator.processLocation(sample2);

      expect(estimator.totalDistanceM, greaterThan(10.0));
      expect(result.speedKmh, greaterThan(1.0));
    });

    test('Accumulates low-speed walking movement when GPS speed stays zero', () {
      final now = DateTime.now();
      final sample1 = LocationSample(
        latitude: -6.200000,
        longitude: 106.816666,
        accuracy: 5.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now,
      );

      // Roughly 0.55 m movement in 1 second.
      final sample2 = LocationSample(
        latitude: -6.199995,
        longitude: 106.816666,
        accuracy: 5.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now.add(const Duration(seconds: 1)),
      );

      estimator.processLocation(sample1);
      final result = estimator.processLocation(sample2);

      expect(estimator.totalDistanceM, greaterThan(0.3));
      expect(result.speedKmh, greaterThan(0.0));
    });

    test('Combines several tiny coordinate steps into one trusted movement', () {
      final now = DateTime.now();
      final sample1 = LocationSample(
        latitude: -6.200000,
        longitude: 106.816666,
        accuracy: 8.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now,
      );

      final sample2 = LocationSample(
        latitude: -6.199998,
        longitude: 106.816666,
        accuracy: 8.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now.add(const Duration(seconds: 1)),
      );

      final sample3 = LocationSample(
        latitude: -6.199996,
        longitude: 106.816666,
        accuracy: 8.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now.add(const Duration(seconds: 2)),
      );

      final sample4 = LocationSample(
        latitude: -6.199994,
        longitude: 106.816666,
        accuracy: 8.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now.add(const Duration(seconds: 3)),
      );

      estimator.processLocation(sample1);
      estimator.processLocation(sample2);
      estimator.processLocation(sample3);
      final result = estimator.processLocation(sample4);

      expect(estimator.totalDistanceM, greaterThan(0.4));
      expect(result.speedKmh, greaterThan(0.0));
    });

    test('Walking mode is more sensitive than car mode for short slow movement', () {
      final now = DateTime.now();
      final walkingEstimator = MovementEstimator(
        profile: TrackingSensitivityProfile.walking,
      );
      final carEstimator = MovementEstimator(
        profile: TrackingSensitivityProfile.car,
      );

      final sample1 = LocationSample(
        latitude: -6.200000,
        longitude: 106.816666,
        accuracy: 2.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now,
      );

      final sample2 = LocationSample(
        latitude: -6.1999985,
        longitude: 106.816666,
        accuracy: 2.0,
        speedMetersPerSecond: 0.0,
        speedKmh: 0.0,
        altitude: 0,
        heading: 0,
        timestamp: now.add(const Duration(seconds: 1)),
      );

      walkingEstimator.processLocation(sample1);
      carEstimator.processLocation(sample1);

      walkingEstimator.processLocation(sample2);
      carEstimator.processLocation(sample2);

      expect(walkingEstimator.totalDistanceM, greaterThan(carEstimator.totalDistanceM));
      expect(walkingEstimator.smoothedSpeedKmh, greaterThanOrEqualTo(carEstimator.smoothedSpeedKmh));
    });
  });
}
