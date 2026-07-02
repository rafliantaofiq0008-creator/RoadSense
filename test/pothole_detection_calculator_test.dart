import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/pothole_detection_calculator.dart';

void main() {
  group('PotholeDetectionCalculator Tests', () {
    test('classifyEventType classifies correctly', () {
      expect(PotholeDetectionCalculator.classifyEventType(2.9), 'smooth_road');
      expect(PotholeDetectionCalculator.classifyEventType(3.0), 'damaged_road');
      expect(PotholeDetectionCalculator.classifyEventType(4.9), 'damaged_road');
      expect(PotholeDetectionCalculator.classifyEventType(5.0), 'pothole');
      expect(PotholeDetectionCalculator.classifyEventType(7.9), 'pothole');
      expect(PotholeDetectionCalculator.classifyEventType(8.0), 'severe_pothole');
    });

    test('classifySeverity classifies correctly', () {
      expect(PotholeDetectionCalculator.classifySeverity(2.9), 'normal');
      expect(PotholeDetectionCalculator.classifySeverity(3.0), 'damaged');
      expect(PotholeDetectionCalculator.classifySeverity(4.9), 'damaged');
      expect(PotholeDetectionCalculator.classifySeverity(5.0), 'pothole');
      expect(PotholeDetectionCalculator.classifySeverity(7.9), 'pothole');
      expect(PotholeDetectionCalculator.classifySeverity(8.0), 'severe_pothole');
    });

    group('shouldDetectEvent', () {
      final now = DateTime.now();

      test('returns false if speed is low', () {
        final result = PotholeDetectionCalculator.shouldDetectEvent(
          vibration: 5.0,
          speedKmh: 4.9,
          gpsAccuracy: 10.0,
          now: now,
          lastEventAt: null,
        );
        expect(result, isFalse);
      });

      test('returns false if GPS accuracy is poor', () {
        final result = PotholeDetectionCalculator.shouldDetectEvent(
          vibration: 5.0,
          speedKmh: 10.0,
          gpsAccuracy: 25.1,
          now: now,
          lastEventAt: null,
        );
        expect(result, isFalse);
      });

      test('returns false if vibration is too low', () {
        final result = PotholeDetectionCalculator.shouldDetectEvent(
          vibration: 2.9,
          speedKmh: 10.0,
          gpsAccuracy: 10.0,
          now: now,
          lastEventAt: null,
        );
        expect(result, isFalse);
      });

      test('returns false during cooldown', () {
        final lastEvent = now.subtract(const Duration(seconds: 2));
        final result = PotholeDetectionCalculator.shouldDetectEvent(
          vibration: 5.0,
          speedKmh: 10.0,
          gpsAccuracy: 10.0,
          now: now,
          lastEventAt: lastEvent,
        );
        expect(result, isFalse);
      });

      test('returns true when valid and outside cooldown', () {
        final lastEvent = now.subtract(const Duration(seconds: 4));
        final result = PotholeDetectionCalculator.shouldDetectEvent(
          vibration: 5.0,
          speedKmh: 10.0,
          gpsAccuracy: 10.0,
          now: now,
          lastEventAt: lastEvent,
        );
        expect(result, isTrue);
      });

      test('returns true when valid and first event', () {
        final result = PotholeDetectionCalculator.shouldDetectEvent(
          vibration: 5.0,
          speedKmh: 10.0,
          gpsAccuracy: 10.0,
          now: now,
          lastEventAt: null,
        );
        expect(result, isTrue);
      });
    });
  });
}
