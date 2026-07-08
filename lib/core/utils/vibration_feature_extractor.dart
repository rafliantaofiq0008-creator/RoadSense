import 'dart:math';

class VibrationFeatures {
  final double verticalPeak;
  final double lateralPeak;
  final double verticalRms;
  final double jerkPeak;
  final double peakToPeak;
  final double impulseDurationMs;
  final double vibrationEnergy;
  final bool isTurning;

  VibrationFeatures({
    required this.verticalPeak,
    required this.lateralPeak,
    required this.verticalRms,
    required this.jerkPeak,
    required this.peakToPeak,
    required this.impulseDurationMs,
    required this.vibrationEnergy,
    required this.isTurning,
  });
}

class VibrationFeatureExtractor {
  // Simple low-pass filter alpha for gravity estimation (isolates ~0 Hz)
  static const double gravityAlpha = 0.1;
  
  // Low-pass filter alpha for smoothing out high-frequency hand shakes / engine vibration (cutoff ~5 Hz)
  static const double filterAlpha = 0.35; 
  
  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 0.0;
  bool _gravityInitialized = false;

  double _filteredDynX = 0.0;
  double _filteredDynY = 0.0;
  double _filteredDynZ = 0.0;

  double _lastAccelX = 0.0;
  double _lastAccelY = 0.0;
  double _lastAccelZ = 0.0;
  DateTime? _lastTimestamp;

  void reset() {
    _gravityInitialized = false;
    _gravityX = 0.0;
    _gravityY = 0.0;
    _gravityZ = 0.0;
    _filteredDynX = 0.0;
    _filteredDynY = 0.0;
    _filteredDynZ = 0.0;
    _lastTimestamp = null;
  }

  /// Update gravity vector using low-pass filter
  void updateGravity(double x, double y, double z) {
    if (!_gravityInitialized) {
      _gravityX = x;
      _gravityY = y;
      _gravityZ = z;
      _gravityInitialized = true;
      return;
    }
    _gravityX = gravityAlpha * x + (1 - gravityAlpha) * _gravityX;
    _gravityY = gravityAlpha * y + (1 - gravityAlpha) * _gravityY;
    _gravityZ = gravityAlpha * z + (1 - gravityAlpha) * _gravityZ;
  }

  /// Extracts advanced features from a single raw sample. 
  /// In a full production app, this would operate over a window of N samples.
  VibrationFeatures extractFeatures(double x, double y, double z, DateTime timestamp) {
    updateGravity(x, y, z);

    // Isolate dynamic acceleration (remove gravity)
    double rawDynX = x - _gravityX;
    double rawDynY = y - _gravityY;
    double rawDynZ = z - _gravityZ;

    // Apply low-pass filter to dynamic acceleration (removes hand shakes/high frequency)
    _filteredDynX = filterAlpha * rawDynX + (1 - filterAlpha) * _filteredDynX;
    _filteredDynY = filterAlpha * rawDynY + (1 - filterAlpha) * _filteredDynY;
    _filteredDynZ = filterAlpha * rawDynZ + (1 - filterAlpha) * _filteredDynZ;

    // Estimate vertical acceleration (projection onto gravity vector) using filtered dynamics
    double gravityMag = sqrt(_gravityX * _gravityX + _gravityY * _gravityY + _gravityZ * _gravityZ);
    double verticalAccel = 0.0;
    if (gravityMag > 0) {
      verticalAccel = (_filteredDynX * _gravityX + _filteredDynY * _gravityY + _filteredDynZ * _gravityZ) / gravityMag;
    }

    // Estimate lateral/horizontal acceleration
    double dynMag = sqrt(_filteredDynX * _filteredDynX + _filteredDynY * _filteredDynY + _filteredDynZ * _filteredDynZ);
    double lateralAccel = sqrt(max(0, dynMag * dynMag - verticalAccel * verticalAccel));

    // Calculate Jerk (derivative of acceleration)
    double jerk = 0.0;
    if (_lastTimestamp != null) {
      double dt = timestamp.difference(_lastTimestamp!).inMilliseconds / 1000.0;
      if (dt > 0) {
        double dAccel = sqrt(pow(x - _lastAccelX, 2) + pow(y - _lastAccelY, 2) + pow(z - _lastAccelZ, 2));
        jerk = dAccel / dt;
      }
    }

    _lastAccelX = x;
    _lastAccelY = y;
    _lastAccelZ = z;
    _lastTimestamp = timestamp;

    // Simple turning logic: if lateral acceleration is high compared to vertical
    bool isTurning = lateralAccel > 2.0 && lateralAccel > verticalAccel.abs() * 1.5;

    // In a continuous window, we would calculate RMS, Peak-to-Peak, and duration.
    // For this single-sample adapter, we approximate:
    return VibrationFeatures(
      verticalPeak: verticalAccel.abs(),
      lateralPeak: lateralAccel,
      verticalRms: verticalAccel.abs(), // Approximation for single sample
      jerkPeak: jerk,
      peakToPeak: verticalAccel.abs() * 2, // Approximation
      impulseDurationMs: 100.0, // Fixed assumption for instantaneous spike
      vibrationEnergy: dynMag * dynMag,
      isTurning: isTurning,
    );
  }
}
