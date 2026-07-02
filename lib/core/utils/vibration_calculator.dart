import 'dart:math';

class VibrationCalculator {
  /// Calculate magnitude using sqrt(x² + y² + z²)
  static double calculateMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Calculate raw vibration by subtracting a baseline from magnitude.
  /// Uses absolute value to capture both positive and negative spikes.
  static double calculateRawVibration(double magnitude, double baseline) {
    return (magnitude - baseline).abs();
  }

  /// Classify road status preview based on vibration threshold
  static String classifyPreviewStatus(double vibration) {
    if (vibration < 1.5) {
      return 'smooth';
    } else if (vibration >= 1.5 && vibration < 3.0) {
      return 'bumpy';
    } else {
      return 'high vibration';
    }
  }
}
