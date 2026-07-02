import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/recording_validator.dart';
import 'package:roadsense/data/models/vibration_sample.dart';
import 'package:roadsense/data/models/location_sample.dart';

void main() {
  group('RecordingValidator Tests', () {
    test('checkReadiness fails if not authenticated', () {
      final loc = LocationSample(
        latitude: 10.0,
        longitude: 20.0,
        altitude: 0,
        speedMetersPerSecond: 2.78,
        speedKmh: 10.0,
        accuracy: 10.0,
        heading: 0,
        timestamp: DateTime.now(),
      );
      final vib = VibrationSample(
        x: 0, y: 0, z: 0,
        magnitude: 0, vibration: 0,
        timestamp: DateTime.now(),
      );

      final result = RecordingValidator.checkReadiness(isAuthenticated: false, latestVibration: vib, latestLocation: loc);
      expect(result.isAuthenticated, isFalse);
      expect(result.isReady, isFalse);
    });

    test('checkReadiness fails if no vibration data', () {
      final loc = LocationSample(
        latitude: 10.0,
        longitude: 20.0,
        altitude: 0,
        speedMetersPerSecond: 2.78,
        speedKmh: 10.0,
        accuracy: 10.0,
        heading: 0,
        timestamp: DateTime.now(),
      );

      final result = RecordingValidator.checkReadiness(isAuthenticated: true, latestVibration: null, latestLocation: loc);
      expect(result.hasAccelerometerData, isFalse);
      expect(result.isReady, isFalse);
    });

    test('checkReadiness fails if no location data', () {
      final vib = VibrationSample(
        x: 0, y: 0, z: 0,
        magnitude: 0, vibration: 0,
        timestamp: DateTime.now(),
      );

      final result = RecordingValidator.checkReadiness(isAuthenticated: true, latestVibration: vib, latestLocation: null);
      expect(result.hasGpsData, isFalse);
      expect(result.isReady, isFalse);
    });

    test('checkReadiness fails if accuracy > 25m', () {
      final vib = VibrationSample(
        x: 0, y: 0, z: 0,
        magnitude: 0, vibration: 0,
        timestamp: DateTime.now(),
      );

      final loc = LocationSample(
        latitude: 10.0,
        longitude: 20.0,
        altitude: 0,
        speedMetersPerSecond: 2.78,
        speedKmh: 10.0,
        accuracy: 26.0,
        heading: 0,
        timestamp: DateTime.now(),
      );

      final result = RecordingValidator.checkReadiness(isAuthenticated: true, latestVibration: vib, latestLocation: loc);
      expect(result.isGpsAccuracyAcceptable, isFalse);
      expect(result.isReady, isFalse);
    });

    test('checkReadiness returns ready if everything is valid', () {
      final vib = VibrationSample(
        x: 0, y: 0, z: 0,
        magnitude: 0, vibration: 0,
        timestamp: DateTime.now(),
      );

      final loc = LocationSample(
        latitude: 10.0,
        longitude: 20.0,
        altitude: 0,
        speedMetersPerSecond: 2.78,
        speedKmh: 10.0,
        accuracy: 15.0,
        heading: 0,
        timestamp: DateTime.now(),
      );

      final result = RecordingValidator.checkReadiness(isAuthenticated: true, latestVibration: vib, latestLocation: loc);
      expect(result.isAuthenticated, isTrue);
      expect(result.hasAccelerometerData, isTrue);
      expect(result.hasGpsData, isTrue);
      expect(result.isGpsAccuracyAcceptable, isTrue);
      expect(result.isReady, isTrue);
    });
  });
}
