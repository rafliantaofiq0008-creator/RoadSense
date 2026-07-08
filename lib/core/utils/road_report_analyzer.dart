import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../data/models/road_reading.dart';
import '../../data/models/road_event.dart';
import 'map_utils.dart'; // To use isValidCoordinate if needed

class RoadReportAnalyzer {
  /// Generates a structured summary from road_readings and road_events for the AI prompt.
  static Map<String, dynamic> generateSummary({
    required List<RoadReading> readings,
    required List<RoadEvent> events,
  }) {
    if (readings.isEmpty) {
      return {
        'error': 'No readings available to analyze.',
      };
    }

    // 1. Sort readings by time
    readings.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    // 2. Trip Duration
    final startTime = readings.first.recordedAt;
    final endTime = readings.last.recordedAt;
    final durationInSeconds = endTime.difference(startTime).inSeconds;
    
    // 3. Distance & Speed & Vibration & GPS
    double totalDistanceMeters = 0.0;
    double maxSpeed = 0.0;
    double sumSpeed = 0.0;
    double maxVibration = 0.0;
    double sumVibration = 0.0;
    double sumGpsAccuracy = 0.0;
    
    final distanceCalc = const Distance();
    
    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      if (r.speed > maxSpeed) maxSpeed = r.speed;
      sumSpeed += r.speed;
      
      if (r.vibration > maxVibration) maxVibration = r.vibration;
      sumVibration += r.vibration;
      
      sumGpsAccuracy += r.gpsAccuracy;
      
      if (i > 0) {
        final prev = readings[i - 1];
        if (MapUtils.isValidCoordinate(prev.latitude, prev.longitude) && 
            MapUtils.isValidCoordinate(r.latitude, r.longitude)) {
          totalDistanceMeters += distanceCalc(
            LatLng(prev.latitude, prev.longitude),
            LatLng(r.latitude, r.longitude),
          );
        }
      }
    }
    
    final int count = readings.length;
    final avgSpeed = sumSpeed / count;
    final avgVibration = sumVibration / count;
    final avgGpsAccuracy = sumGpsAccuracy / count;

    // 4. Events
    int damagedRoadCount = 0;
    int potholeCount = 0;
    int severePotholeCount = 0;
    
    for (final e in events) {
      if (e.eventType == 'damaged_road') {
        damagedRoadCount++;
      } else if (e.eventType == 'pothole') {
        potholeCount++;
      } else if (e.eventType == 'severe_pothole') {
        severePotholeCount++;
      }
    }

    // 5. Segmentation (every 500m)
    final segments = _segmentRoute(readings, events, distanceCalc, 500.0);

    return {
      'overview': {
        'total_readings': count,
        'total_events': events.length,
        'duration_seconds': durationInSeconds,
        'estimated_distance_meters': totalDistanceMeters.round(),
        'average_speed_kmh': avgSpeed.toStringAsFixed(2),
        'max_speed_kmh': maxSpeed.toStringAsFixed(2),
        'average_vibration': avgVibration.toStringAsFixed(2),
        'max_vibration': maxVibration.toStringAsFixed(2),
        'average_gps_accuracy_m': avgGpsAccuracy.toStringAsFixed(2),
      },
      'event_breakdown': {
        'damaged_road': damagedRoadCount,
        'pothole': potholeCount,
        'severe_pothole': severePotholeCount,
      },
      'segments': segments,
    };
  }

  static List<Map<String, dynamic>> _segmentRoute(
    List<RoadReading> readings,
    List<RoadEvent> events,
    Distance distanceCalc,
    double segmentLengthMeters,
  ) {
    List<Map<String, dynamic>> segments = [];
    if (readings.isEmpty) return segments;

    double currentSegmentDistance = 0.0;
    double accumulatedTotalDistance = 0.0;
    
    int segReadingsCount = 0;
    double segMaxVibration = 0.0;
    double segSumVibration = 0.0;
    
    int segmentIndex = 1;
    double startRange = 0.0;
    
    DateTime segStartTime = readings.first.recordedAt;
    DateTime segEndTime = readings.first.recordedAt;

    void pushSegment(double endRange) {
      if (segReadingsCount == 0) return;
      
      final segAvgVibration = segSumVibration / segReadingsCount;
      
      // Find events that fall into this time window
      // Assuming events are also ordered by time roughly, or we just filter
      final segEvents = events.where((e) => 
        (e.recordedAt.isAfter(segStartTime) || e.recordedAt.isAtSameMomentAs(segStartTime)) &&
        (e.recordedAt.isBefore(segEndTime) || e.recordedAt.isAtSameMomentAs(segEndTime))
      ).toList();

      final riskLevel = _calculateRiskLevel(segEvents, segMaxVibration);

      segments.add({
        'segment_number': segmentIndex,
        'distance_range_meters': '${startRange.round()} - ${endRange.round()}',
        'readings_count': segReadingsCount,
        'event_count': segEvents.length,
        'max_vibration': segMaxVibration.toStringAsFixed(2),
        'average_vibration': segAvgVibration.toStringAsFixed(2),
        'risk_level': riskLevel,
      });

      segmentIndex++;
      startRange = endRange;
      
      // Reset accumulators
      currentSegmentDistance = 0.0;
      segReadingsCount = 0;
      segMaxVibration = 0.0;
      segSumVibration = 0.0;
    }

    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      segReadingsCount++;
      if (r.vibration > segMaxVibration) segMaxVibration = r.vibration;
      segSumVibration += r.vibration;
      segEndTime = r.recordedAt;

      if (i > 0) {
        final prev = readings[i - 1];
        if (MapUtils.isValidCoordinate(prev.latitude, prev.longitude) && 
            MapUtils.isValidCoordinate(r.latitude, r.longitude)) {
          final dist = distanceCalc(
            LatLng(prev.latitude, prev.longitude),
            LatLng(r.latitude, r.longitude),
          );
          currentSegmentDistance += dist;
          accumulatedTotalDistance += dist;
        }
      }

      if (currentSegmentDistance >= segmentLengthMeters) {
        pushSegment(accumulatedTotalDistance);
        segStartTime = r.recordedAt;
      }
    }

    // Push remainder
    if (segReadingsCount > 0) {
      pushSegment(accumulatedTotalDistance);
    }

    return segments;
  }

  static String _calculateRiskLevel(List<RoadEvent> events, double maxVibration) {
    bool hasSevere = events.any((e) => e.eventType == 'severe_pothole');
    bool hasPothole = events.any((e) => e.eventType == 'pothole');
    bool hasDamaged = events.any((e) => e.eventType == 'damaged_road');
    
    // critical: severe_pothole exists or max vibration >= 8.0 and repeated events exist
    if (hasSevere || (maxVibration >= 8.0 && events.length > 1)) {
      return 'critical';
    }
    // high: pothole exists or max vibration >= 5.0
    if (hasPothole || maxVibration >= 5.0) {
      return 'high';
    }
    // medium: damaged_road exists or max vibration >= 3.0
    if (hasDamaged || maxVibration >= 3.0) {
      return 'medium';
    }
    // low: no events and max vibration < 3.0
    return 'low';
  }
}
