class PotholeDetectionCalculator {
  static const double minVibration = 3.0;
  static const double minSpeedKmh = 5.0;
  static const double maxGpsAccuracy = 25.0;
  static const Duration cooldownDuration = Duration(seconds: 3);

  static String classifyEventType(double vibration) {
    if (vibration >= 8.0) return 'severe_pothole';
    if (vibration >= 5.0) return 'pothole';
    if (vibration >= 3.0) return 'damaged_road';
    return 'smooth_road';
  }

  static String classifySeverity(double vibration) {
    if (vibration >= 8.0) return 'severe_pothole';
    if (vibration >= 5.0) return 'pothole';
    if (vibration >= 3.0) return 'damaged';
    return 'normal';
  }

  static bool shouldDetectEvent({
    required double vibration,
    required double speedKmh,
    required double gpsAccuracy,
    required DateTime now,
    required DateTime? lastEventAt,
  }) {
    if (vibration < minVibration) return false;
    if (speedKmh < minSpeedKmh) return false;
    if (gpsAccuracy > maxGpsAccuracy) return false;

    if (lastEventAt != null) {
      final diff = now.difference(lastEventAt);
      if (diff < cooldownDuration) return false;
    }

    return true;
  }
}
