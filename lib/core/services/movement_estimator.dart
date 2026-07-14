import 'dart:math';
import '../config/tracking_sensitivity.dart';
import '../../data/models/location_sample.dart';

class MovementEstimator {
  double totalDistanceM = 0.0;
  LocationSample? _lastLocation;
  LocationSample? _candidateMovementStart;
  TrackingSensitivityProfile _profile;
  
  // Smoothing config
  final double alpha = 0.3; // Exponential smoothing factor for speed
  double _smoothedSpeedKmh = 0.0;
  double get smoothedSpeedKmh => _smoothedSpeedKmh;
  TrackingSensitivityProfile get profile => _profile;

  MovementEstimator({TrackingSensitivityProfile? profile})
      : _profile = profile ?? TrackingSensitivityProfile.car;

  void configureProfile(TrackingSensitivityProfile profile) {
    _profile = profile;
  }

  void reset() {
    totalDistanceM = 0.0;
    _lastLocation = null;
    _candidateMovementStart = null;
    _smoothedSpeedKmh = 0.0;
  }

  /// Processes a new location sample and returns an updated LocationSample
  /// with fused speed and noise-rejected coordinates.
  LocationSample processLocation(LocationSample current) {
    if (_lastLocation == null) {
      _lastLocation = current;
      _smoothedSpeedKmh = current.speedKmh;
      return current;
    }

    final LocationSample referenceLocation = _candidateMovementStart ?? _lastLocation!;

    final double distanceM = _calculateHaversineDistance(
      referenceLocation.latitude,
      referenceLocation.longitude,
      current.latitude,
      current.longitude,
    );

    final double rawTimeDeltaSeconds =
        current.timestamp.difference(referenceLocation.timestamp).inMilliseconds / 1000.0;
    // Some Android GPS providers can emit updated coordinates while keeping
    // speed at 0 and not advancing the sample timestamp reliably. The app
    // samples location roughly once per second, so we use a 1s fallback to
    // avoid classifying real walking/running motion as stationary forever.
    final double timeDeltaSeconds = rawTimeDeltaSeconds > 0 ? rawTimeDeltaSeconds : 1.0;

    double derivedSpeedKmh = 0.0;
    derivedSpeedKmh = (distanceM / timeDeltaSeconds) * 3.6;

    final double accuracyNoiseGateM = _trustedMovementThreshold(
      referenceLocation.accuracy,
      current.accuracy,
    );
    final bool hasMeaningfulCoordinateMovement = distanceM >= accuracyNoiseGateM;

    // Fuse speed: Many Android devices report 0 speed if movement is slow or inconsistent
    double fusedSpeedKmh = current.speedKmh;
    
    if (current.speedKmh < 1.0 &&
        derivedSpeedKmh >= _profile.minMovementSpeedKmh &&
        hasMeaningfulCoordinateMovement) {
      // If GPS says we are stopped, but coordinates show credible movement,
      // trust the derived speed. This helps for walking/running tests where
      // some Android providers keep reporting 0 km/h.
      if (distanceM >= _profile.minCoordinateStepM) {
        fusedSpeedKmh = derivedSpeedKmh;
      }
    } else if (current.speedKmh > 0 && derivedSpeedKmh > 0) {
      // Blend to reduce spikes, but give hardware speed slightly more weight if it's moving fast
      fusedSpeedKmh = (current.speedKmh * 0.6) + (derivedSpeedKmh * 0.4);
    }

    // Smooth speed
    _smoothedSpeedKmh = (alpha * fusedSpeedKmh) + ((1 - alpha) * _smoothedSpeedKmh);

    // Strict stationary check to stop speed creeping up while at a stoplight due to GPS drift
    // Since interval is ~1 second, a small coordinate change can be pure GPS jitter.
    final bool isStationary = !hasMeaningfulCoordinateMovement &&
        derivedSpeedKmh < _profile.minMovementSpeedKmh &&
        current.speedKmh < _profile.minMovementSpeedKmh;

    if (isStationary) {
      _smoothedSpeedKmh = 0.0;
      _candidateMovementStart ??= _lastLocation;

      final bool candidateExpired =
          current.timestamp.difference(_candidateMovementStart!.timestamp) >= _profile.maxCandidateWindow;
      if (candidateExpired) {
        _lastLocation = current;
        _candidateMovementStart = null;
      }
    }

    // Accumulate distance
    if (!isStationary && hasMeaningfulCoordinateMovement) {
      // Accumulate only when movement beats the GPS noise gate so we can
      // support low-speed testing without counting stationary jitter.
      totalDistanceM += distanceM;
      _lastLocation = current;
      _candidateMovementStart = null;
    } else if (!isStationary && _candidateMovementStart == null) {
      // Keep the last accepted location as the anchor so several small
      // consecutive movements can accumulate into a trusted displacement.
      _candidateMovementStart = _lastLocation;
    } else if (rawTimeDeltaSeconds > 5.0) {
      // If the provider stalls for too long, refresh the anchor to avoid
      // using stale timestamps for subsequent speed estimation.
      _lastLocation = current;
      _candidateMovementStart = null;
    }

    return current.copyWith(
      speedKmh: _smoothedSpeedKmh, // Override raw speed with smoothed speed
    );
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Earth radius in meters
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;

    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  double _trustedMovementThreshold(double previousAccuracyM, double currentAccuracyM) {
    final double bestAccuracyM = min(previousAccuracyM, currentAccuracyM);
    final double derivedGate = bestAccuracyM * 0.05;
    return derivedGate.clamp(_profile.minCoordinateStepM, _profile.maxNoiseGateM);
  }
}
