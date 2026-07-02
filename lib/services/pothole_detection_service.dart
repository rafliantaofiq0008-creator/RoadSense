import '../core/utils/pothole_detection_calculator.dart';
import '../data/models/location_sample.dart';
import '../data/models/pothole_detection_result.dart';
import '../data/models/vibration_sample.dart';

class PotholeDetectionService {
  DateTime? _lastEventAt;

  /// Process live sensor data and return a PotholeDetectionResult if an event is detected
  PotholeDetectionResult? processSensorData(VibrationSample vibrationSample, LocationSample? locationSample) {
    if (locationSample == null) return null;

    final now = DateTime.now().toUtc();

    final isEvent = PotholeDetectionCalculator.shouldDetectEvent(
      vibration: vibrationSample.vibration,
      speedKmh: locationSample.speedKmh,
      gpsAccuracy: locationSample.accuracy,
      now: now,
      lastEventAt: _lastEventAt,
    );

    if (isEvent) {
      _lastEventAt = now;
      return PotholeDetectionResult(
        timestamp: now,
        eventType: PotholeDetectionCalculator.classifyEventType(vibrationSample.vibration),
        severity: PotholeDetectionCalculator.classifySeverity(vibrationSample.vibration),
        magnitude: vibrationSample.magnitude,
        vibration: vibrationSample.vibration,
        speed: locationSample.speedKmh,
        latitude: locationSample.latitude,
        longitude: locationSample.longitude,
        gpsAccuracy: locationSample.accuracy,
      );
    }

    return null;
  }
}
