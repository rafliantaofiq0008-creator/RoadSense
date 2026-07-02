import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/trip_summary_calculator.dart';
import 'package:roadsense/data/models/road_reading.dart';
import 'package:roadsense/data/models/road_session.dart';

void main() {
  group('TripSummaryCalculator Tests', () {
    final baseSession = RoadSession(
      id: 'session-123',
      userId: 'user-123',
      title: 'Test Trip',
      startTime: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
    );

    test('calculateSummary handles empty readings correctly', () {
      final updated = TripSummaryCalculator.calculateSummary(baseSession, []);
      
      expect(updated.averageSpeed, 0.0);
      expect(updated.maxSpeed, 0.0);
      expect(updated.maxVibration, 0.0);
    });

    test('calculateSummary correctly calculates max and average', () {
      final readings = [
        RoadReading(
          id: '1', sessionId: 'session-123', userId: 'user-123',
          speed: 10.0, vibration: 0.5,
          accelerationX: 0, accelerationY: 0, accelerationZ: 0, magnitude: 0,
          latitude: 0, longitude: 0, gpsAccuracy: 10,
          recordedAt: DateTime.now().toUtc(),
        ),
        RoadReading(
          id: '2', sessionId: 'session-123', userId: 'user-123',
          speed: 20.0, vibration: 2.0,
          accelerationX: 0, accelerationY: 0, accelerationZ: 0, magnitude: 0,
          latitude: 0, longitude: 0, gpsAccuracy: 10,
          recordedAt: DateTime.now().toUtc(),
        ),
        RoadReading(
          id: '3', sessionId: 'session-123', userId: 'user-123',
          speed: 0.0, vibration: 1.1,
          accelerationX: 0, accelerationY: 0, accelerationZ: 0, magnitude: 0,
          latitude: 0, longitude: 0, gpsAccuracy: 10,
          recordedAt: DateTime.now().toUtc(),
        ),
      ];

      final updated = TripSummaryCalculator.calculateSummary(baseSession, readings);
      
      expect(updated.averageSpeed, 10.0); // (10 + 20 + 0) / 3
      expect(updated.maxSpeed, 20.0);
      expect(updated.maxVibration, 2.0);
    });
  });
}
