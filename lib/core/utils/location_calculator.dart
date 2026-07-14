class LocationCalculator {
  /// Converts speed from meters per second to kilometers per hour.
  static double metersPerSecondToKmh(double speedMetersPerSecond) {
    return speedMetersPerSecond * 3.6;
  }

  /// Determines if the user is moving based on the current speed in km/h.
  /// Currently uses a simple threshold of 5.0 km/h.
  static bool isMoving(double speedKmh, {double thresholdKmh = 5.0}) {
    return speedKmh >= thresholdKmh;
  }

  /// Determines if the GPS accuracy is acceptable for data collection.
  /// Currently requires accuracy to be 25 meters or better.
  static bool isGpsAccuracyAcceptable(double accuracyMeters) {
    return accuracyMeters <= 25.0;
  }
}
