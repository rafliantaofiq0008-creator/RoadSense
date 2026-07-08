import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/road_report_analyzer.dart';
import 'package:roadsense/data/models/road_reading.dart';
import 'package:roadsense/data/models/road_event.dart';

void main() {
  group('RoadReportAnalyzer', () {
    test('generateSummary returns error for empty readings', () {
      final summary = RoadReportAnalyzer.generateSummary(readings: [], events: []);
      expect(summary.containsKey('error'), isTrue);
    });

    test('generateSummary calculates duration, speed, and segments correctly', () {
      final now = DateTime.now();
      final r1 = RoadReading(
        id: 'r1',
        sessionId: 's1',
        userId: 'u1',
        accelerationX: 0,
        accelerationY: 0,
        accelerationZ: 0,
        magnitude: 0,
        vibration: 2.0,
        speed: 10.0,
        latitude: -6.200000,
        longitude: 106.816666,
        gpsAccuracy: 5.0,
        recordedAt: now,
      );
      final r2 = RoadReading(
        id: 'r2',
        sessionId: 's1',
        userId: 'u1',
        accelerationX: 0,
        accelerationY: 0,
        accelerationZ: 0,
        magnitude: 0,
        vibration: 4.0,
        speed: 20.0,
        latitude: -6.205000, // Roughly ~500m away
        longitude: 106.816666,
        gpsAccuracy: 5.0,
        recordedAt: now.add(const Duration(seconds: 10)),
      );

      final events = [
        RoadEvent(
          id: 'e1',
          sessionId: 's1',
          userId: 'u1',
          eventType: 'pothole',
          severity: 'medium',
          magnitude: 0,
          vibration: 5.5,
          speed: 15.0,
          latitude: -6.202500,
          longitude: 106.816666,
          gpsAccuracy: 5.0,
          recordedAt: now.add(const Duration(seconds: 5)),
        )
      ];

      final summary = RoadReportAnalyzer.generateSummary(
        readings: [r1, r2],
        events: events,
      );

      expect(summary.containsKey('error'), isFalse);
      
      final overview = summary['overview'] as Map<String, dynamic>;
      expect(overview['total_readings'], 2);
      expect(overview['total_events'], 1);
      expect(overview['duration_seconds'], 10);
      expect(overview['max_speed_kmh'], '20.00');
      expect(overview['average_speed_kmh'], '15.00');
      expect(overview['max_vibration'], '4.00');
      
      final eventBreakdown = summary['event_breakdown'] as Map<String, dynamic>;
      expect(eventBreakdown['pothole'], 1);
      expect(eventBreakdown['damaged_road'], 0);
      expect(eventBreakdown['severe_pothole'], 0);
      
      final segments = summary['segments'] as List<Map<String, dynamic>>;
      expect(segments.isNotEmpty, isTrue);
      // Because we have pothole event with vibration 5.5 in the segment timeframe
      // Wait, the event might fall into the first segment
      expect(segments[0]['event_count'], 1);
      expect(segments[0]['risk_level'], 'high'); // Since pothole event exists
    });
  });
}
