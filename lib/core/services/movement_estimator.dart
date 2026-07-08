import 'dart:math';
import '../../data/models/location_sample.dart';

class MovementEstimator {
  double totalDistanceM = 0.0;
  LocationSample? _lastLocation;
  
  // Smoothing config
  final double alpha = 0.3; // Exponential smoothing factor for speed
  double _smoothedSpeedKmh = 0.0;
  double get smoothedSpeedKmh => _smoothedSpeedKmh;

  void reset() {
    totalDistanceM = 0.0;
    _lastLocation = null;
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

    final double distanceM = _calculateHaversineDistance(
      _lastLocation!.latitude,
      _lastLocation!.longitude,
      current.latitude,
      current.longitude,
    );

    final double timeDeltaSeconds = current.timestamp.difference(_lastLocation!.timestamp).inMilliseconds / 1000.0;

    double derivedSpeedKmh = 0.0;
    if (timeDeltaSeconds > 0) {
      derivedSpeedKmh = (distanceM / timeDeltaSeconds) * 3.6;
    }

    // Fuse speed: Many Android devices report 0 speed if movement is slow or inconsistent
    double fusedSpeedKmh = current.speedKmh;
    
    if (current.speedKmh < 1.0 && derivedSpeedKmh > 2.0) {
      // If GPS says we are stopped, but coordinates show significant movement, trust coordinates
      if (distanceM > current.accuracy * 0.5) {
        fusedSpeedKmh = derivedSpeedKmh;
      }
    } else if (current.speedKmh > 0 && derivedSpeedKmh > 0) {
      // Blend to reduce spikes
      fusedSpeedKmh = (current.speedKmh + derivedSpeedKmh) / 2.0;
    }

    // Smooth speed
    _smoothedSpeedKmh = (alpha * fusedSpeedKmh) + ((1 - alpha) * _smoothedSpeedKmh);

    // Strict stationary check to stop speed creeping up while at a stoplight due to GPS drift
    bool isStationary = (derivedSpeedKmh < 2.0 && current.speedKmh < 2.0) || 
                        (distanceM < current.accuracy && current.speedKmh < 1.0);

    if (isStationary) {
      _smoothedSpeedKmh = 0.0;
    }

    // Accumulate distance
    if (!isStationary && distanceM > 0.5 && distanceM > (current.accuracy * 0.1)) {
      totalDistanceM += distanceM;
      _lastLocation = current;
    } else if (timeDeltaSeconds > 5.0 || isStationary) {
       // Force update last location to prevent stale time deltas if standing still
       _lastLocation = current;
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
}
