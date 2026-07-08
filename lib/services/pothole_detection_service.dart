
import '../core/utils/vibration_feature_extractor.dart';
import '../data/models/location_sample.dart';
import '../data/models/pothole_detection_result.dart';
import '../data/models/vibration_sample.dart';

class PotholeDetectionService {
  DateTime? _lastEventAt;
  final VibrationFeatureExtractor _featureExtractor = VibrationFeatureExtractor();
  
  // Adaptive thresholds (can be updated from vehicle profile later)
  double _baselineMean = 1.0;
  double _baselineStd = 0.5;

  void reset() {
    _lastEventAt = null;
    _featureExtractor.reset();
  }

  void updateCalibration(double mean, double std) {
    _baselineMean = mean;
    _baselineStd = std;
  }

  /// Process live sensor data using a two-stage detection pipeline
  PotholeDetectionResult? processSensorData(VibrationSample vibrationSample, LocationSample? locationSample) {
    // 1. Extract Advanced Features
    final features = _featureExtractor.extractFeatures(
      vibrationSample.x,
      vibrationSample.y,
      vibrationSample.z,
      vibrationSample.timestamp,
    );

    // Adaptive thresholds
    final double damagedThreshold = _baselineMean + 3 * _baselineStd;
    final double potholeThreshold = _baselineMean + 5 * _baselineStd;
    final double severeThreshold = _baselineMean + 7 * _baselineStd;

    // Stage 1: Candidate Extraction (Is there a significant vertical impulse or jerk?)
    bool isCandidate = features.verticalPeak >= damagedThreshold || features.jerkPeak >= 50.0;
    
    if (!isCandidate) return null;

    final now = DateTime.now().toUtc();
    String? rejectionReason;
    int confidenceScore = 100;
    
    // Stage 2: Validation
    
    // Check speed
    final double speed = locationSample?.speedKmh ?? 0.0;
    if (speed < 8.0) {
      rejectionReason = 'ignored_low_speed';
      confidenceScore -= 80;
    }

    // Check GPS accuracy
    final double accuracy = locationSample?.accuracy ?? 999.0;
    if (accuracy > 25.0) {
      rejectionReason ??= 'ignored_poor_gps';
      confidenceScore -= 40;
    }

    // Check Turning / Phone Motion
    if (features.isTurning) {
      rejectionReason ??= 'ignored_turning';
      confidenceScore -= 60;
    }

    // Cooldown check
    if (_lastEventAt != null) {
      final diff = now.difference(_lastEventAt!);
      if (diff < const Duration(milliseconds: 2500)) {
        rejectionReason ??= 'ignored_cooldown';
        confidenceScore -= 50;
      }
    }

    // Classify Event Type based on vertical peak and adaptive threshold
    String eventType = 'smooth_road';
    String severity = 'normal';
    
    if (features.verticalPeak >= severeThreshold) {
      eventType = 'severe_pothole';
      severity = 'severe_pothole';
    } else if (features.verticalPeak >= potholeThreshold) {
      eventType = 'pothole';
      severity = 'pothole';
    } else if (features.verticalPeak >= damagedThreshold) {
      eventType = 'damaged_road';
      severity = 'damaged';
    }

    // If completely rejected, do not return as a road event unless we want to log diagnostics
    // We will return it with validationStatus = 'rejected' so the caller can decide to log or drop.
    String validationStatus = rejectionReason == null ? 'valid' : 'rejected';
    
    // Ensure score bounds
    if (confidenceScore < 0) confidenceScore = 0;
    if (validationStatus == 'valid') {
       _lastEventAt = now;
    }

    return PotholeDetectionResult(
      timestamp: now,
      eventType: eventType,
      severity: severity,
      magnitude: vibrationSample.magnitude,
      vibration: features.verticalPeak, // Replace raw vibration with orientation-aware vertical peak
      speed: speed,
      latitude: locationSample?.latitude ?? 0.0,
      longitude: locationSample?.longitude ?? 0.0,
      gpsAccuracy: accuracy,
      reason: rejectionReason,
      confidenceScore: confidenceScore,
      verticalPeak: features.verticalPeak,
      lateralPeak: features.lateralPeak,
      jerkPeak: features.jerkPeak,
      validationStatus: validationStatus,
      rejectionReason: rejectionReason,
    );
  }
}
