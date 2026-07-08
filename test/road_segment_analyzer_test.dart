import 'package:flutter_test/flutter_test.dart';
import '../lib/core/services/road_segment_analyzer.dart';
import '../lib/data/models/location_sample.dart';
import '../lib/data/models/pothole_detection_result.dart';
import '../lib/data/models/vibration_sample.dart';

void main() {
  group('RoadSegmentAnalyzer Tests', () {
    late RoadSegmentAnalyzer analyzer;

    setUp(() {
      analyzer = RoadSegmentAnalyzer();
    });

    test('Short distance (<50m) results in not_assessed', () {
      final analysis = RoadSegmentAnalyzer.buildSegmentAnalysis(
        segmentIndex: 1,
        startDistanceM: 0,
        endDistanceM: 40,
        locations: [
          LocationSample(latitude: 0, longitude: 0, speedKmh: 20, speedMetersPerSecond: 20 / 3.6, accuracy: 5, timestamp: DateTime.now())
        ],
        vibrations: [],
        events: [],
        userId: '123',
        sessionId: '456',
      );
      
      expect(analysis.roadCondition, 'not_assessed');
      expect(analysis.conditionScore, isNull);
    });

    test('Low speed (<5 km/h) results in not_assessed', () {
      final analysis = RoadSegmentAnalyzer.buildSegmentAnalysis(
        segmentIndex: 1,
        startDistanceM: 0,
        endDistanceM: 100,
        locations: [
          LocationSample(latitude: 0, longitude: 0, speedKmh: 3, speedMetersPerSecond: 3 / 3.6, accuracy: 5, timestamp: DateTime.now())
        ],
        vibrations: [],
        events: [],
        userId: '123',
        sessionId: '456',
      );
      
      expect(analysis.roadCondition, 'not_assessed');
    });

    test('Valid speed + no events + low vibration = good', () {
      final analysis = RoadSegmentAnalyzer.buildSegmentAnalysis(
        segmentIndex: 1,
        startDistanceM: 0,
        endDistanceM: 100,
        locations: [
          LocationSample(latitude: 0, longitude: 0, speedKmh: 30, speedMetersPerSecond: 30 / 3.6, accuracy: 5, timestamp: DateTime.now())
        ],
        vibrations: [
          VibrationSample(x: 0, y: 0, z: 9.81, magnitude: 1.0, vibration: 1.0, timestamp: DateTime.now())
        ],
        events: [],
        userId: '123',
        sessionId: '456',
      );
      
      expect(analysis.roadCondition, 'good');
      expect(analysis.conditionScore, 20.0);
    });

    test('Valid speed + pothole event = pothole_indication', () {
      final analysis = RoadSegmentAnalyzer.buildSegmentAnalysis(
        segmentIndex: 1,
        startDistanceM: 0,
        endDistanceM: 100,
        locations: [
          LocationSample(latitude: 0, longitude: 0, speedKmh: 30, speedMetersPerSecond: 30 / 3.6, accuracy: 5, timestamp: DateTime.now())
        ],
        vibrations: [],
        events: [
          PotholeDetectionResult(
            timestamp: DateTime.now(),
            eventType: 'pothole',
            severity: 'pothole',
            magnitude: 5.0,
            vibration: 5.0,
            speed: 30.0,
            latitude: 0,
            longitude: 0,
            gpsAccuracy: 5.0,
            confidenceScore: 100,
            verticalPeak: 5.0,
            lateralPeak: 1.0,
            jerkPeak: 10.0,
            validationStatus: 'valid',
          )
        ],
        userId: '123',
        sessionId: '456',
      );
      
      expect(analysis.roadCondition, 'pothole_indication');
      expect(analysis.conditionScore, 70.0); // 65 + (1 * 5)
    });

    test('Valid speed + severe event = severe_damage', () {
      final analysis = RoadSegmentAnalyzer.buildSegmentAnalysis(
        segmentIndex: 1,
        startDistanceM: 0,
        endDistanceM: 100,
        locations: [
          LocationSample(latitude: 0, longitude: 0, speedKmh: 30, speedMetersPerSecond: 30 / 3.6, accuracy: 5, timestamp: DateTime.now())
        ],
        vibrations: [],
        events: [
          PotholeDetectionResult(
            timestamp: DateTime.now(),
            eventType: 'severe_pothole',
            severity: 'severe_pothole',
            magnitude: 8.0,
            vibration: 8.0,
            speed: 30.0,
            latitude: 0,
            longitude: 0,
            gpsAccuracy: 5.0,
            confidenceScore: 100,
            verticalPeak: 8.0,
            lateralPeak: 1.0,
            jerkPeak: 15.0,
            validationStatus: 'valid',
          )
        ],
        userId: '123',
        sessionId: '456',
      );
      
      expect(analysis.roadCondition, 'severe_damage');
      expect(analysis.conditionScore, 90.0); // 85 + (1 * 5)
    });
  });
}
