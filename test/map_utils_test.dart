import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:roadsense/core/utils/map_utils.dart';
import 'package:roadsense/data/models/road_reading.dart';

void main() {
  group('MapUtils Tests', () {
    test('isValidCoordinate returns true for valid coordinates', () {
      expect(MapUtils.isValidCoordinate(0, 0), isTrue);
      expect(MapUtils.isValidCoordinate(90, 180), isTrue);
      expect(MapUtils.isValidCoordinate(-90, -180), isTrue);
      expect(MapUtils.isValidCoordinate(45.5, -122.6), isTrue);
    });

    test('isValidCoordinate returns false for invalid latitude', () {
      expect(MapUtils.isValidCoordinate(90.1, 0), isFalse);
      expect(MapUtils.isValidCoordinate(-90.1, 0), isFalse);
    });

    test('isValidCoordinate returns false for invalid longitude', () {
      expect(MapUtils.isValidCoordinate(0, 180.1), isFalse);
      expect(MapUtils.isValidCoordinate(0, -180.1), isFalse);
    });

    test('isValidCoordinate returns false for null coordinates', () {
      expect(MapUtils.isValidCoordinate(null, 0), isFalse);
      expect(MapUtils.isValidCoordinate(0, null), isFalse);
      expect(MapUtils.isValidCoordinate(null, null), isFalse);
    });

    test('filterValidRoutePoints extracts only valid coordinates', () {
      final readings = <RoadReading>[
        RoadReading(id: '1', sessionId: 's1', userId: 'u1', accelerationX: 0, accelerationY: 0, accelerationZ: 0, magnitude: 0, vibration: 0, speed: 0, gpsAccuracy: 0, recordedAt: DateTime.now(), latitude: 10, longitude: 20),
        RoadReading(id: '2', sessionId: 's1', userId: 'u1', accelerationX: 0, accelerationY: 0, accelerationZ: 0, magnitude: 0, vibration: 0, speed: 0, gpsAccuracy: 0, recordedAt: DateTime.now(), latitude: 200, longitude: 20), // invalid lat
        RoadReading(id: '3', sessionId: 's1', userId: 'u1', accelerationX: 0, accelerationY: 0, accelerationZ: 0, magnitude: 0, vibration: 0, speed: 0, gpsAccuracy: 0, recordedAt: DateTime.now(), latitude: 95, longitude: 20), // invalid lat
        RoadReading(id: '4', sessionId: 's1', userId: 'u1', accelerationX: 0, accelerationY: 0, accelerationZ: 0, magnitude: 0, vibration: 0, speed: 0, gpsAccuracy: 0, recordedAt: DateTime.now(), latitude: 15, longitude: 25),
      ];
      
      final points = MapUtils.filterValidRoutePoints(readings);
      expect(points.length, 2);
      expect(points[0].latitude, 10);
      expect(points[0].longitude, 20);
      expect(points[1].latitude, 15);
      expect(points[1].longitude, 25);
    });

    test('downsampleRoutePoints returns same list if length <= maxPoints', () {
      final points = List.generate(5, (i) => LatLng(i.toDouble(), i.toDouble()));
      final downsampled = MapUtils.downsampleRoutePoints(points, maxPoints: 10);
      expect(downsampled.length, 5);
      expect(downsampled, points);
    });

    test('downsampleRoutePoints reduces points to maxPoints while keeping endpoints', () {
      final points = List.generate(100, (i) => LatLng(i.toDouble(), i.toDouble()));
      final downsampled = MapUtils.downsampleRoutePoints(points, maxPoints: 10);
      
      expect(downsampled.length, inInclusiveRange(10, 11));
      expect(downsampled.first.latitude, 0); // First point
      expect(downsampled.last.latitude, 99); // Last point
    });

    test('calculateMapCenter returns first route point if available', () {
      final route = [const LatLng(10, 10), const LatLng(20, 20)];
      final events = [const LatLng(30, 30)];
      
      final center = MapUtils.calculateMapCenter(routePoints: route, eventPoints: events);
      expect(center, const LatLng(10, 10));
    });

    test('calculateMapCenter returns first event point if route is empty', () {
      final route = <LatLng>[];
      final events = [const LatLng(30, 30), const LatLng(40, 40)];
      
      final center = MapUtils.calculateMapCenter(routePoints: route, eventPoints: events);
      expect(center, const LatLng(30, 30));
    });

    test('calculateMapCenter returns default (0,0) if both are empty', () {
      final center = MapUtils.calculateMapCenter(routePoints: [], eventPoints: []);
      expect(center, const LatLng(0, 0));
    });
  });
}
