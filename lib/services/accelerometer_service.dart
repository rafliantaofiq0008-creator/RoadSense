import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/utils/vibration_calculator.dart';
import '../data/models/vibration_sample.dart';

class AccelerometerService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final _vibrationStreamController = StreamController<VibrationSample>.broadcast();
  
  VibrationSample? _currentSample;
  DateTime? _lastSampleTime;
  
  // Throttle updates to avoid flooding the UI.
  final Duration _updateInterval = const Duration(milliseconds: 100);

  double _baseline = 0.0;

  Stream<VibrationSample> get vibrationStream => _vibrationStreamController.stream;
  VibrationSample? get currentSample => _currentSample;
  bool get isRunning => _subscription != null;

  void startStream() {
    if (_subscription != null) {
      debugPrint('AccelerometerService: Stream is already running.');
      return;
    }

    _subscription = userAccelerometerEventStream().listen(
      (UserAccelerometerEvent event) {
        final now = DateTime.now();

        // Throttle updates
        if (_lastSampleTime != null && now.difference(_lastSampleTime!) < _updateInterval) {
          return;
        }
        _lastSampleTime = now;

        final magnitude = VibrationCalculator.calculateMagnitude(event.x, event.y, event.z);
        // For user accelerometer, gravity is already removed. 
        // We can apply baseline if needed, but often magnitude itself represents the raw movement force.
        final vibration = VibrationCalculator.calculateRawVibration(magnitude, _baseline);

        final sample = VibrationSample(
          timestamp: now,
          x: event.x,
          y: event.y,
          z: event.z,
          magnitude: magnitude,
          vibration: vibration,
        );

        _currentSample = sample;
        _vibrationStreamController.add(sample);
      },
      onError: (error) {
        debugPrint('AccelerometerService Error: $error');
      },
    );
  }

  void stopStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  void resetBaseline() {
    if (_currentSample != null) {
      _baseline = _currentSample!.magnitude;
      debugPrint('AccelerometerService: Baseline reset to $_baseline');
    }
  }

  void dispose() {
    stopStream();
    _vibrationStreamController.close();
  }
}
