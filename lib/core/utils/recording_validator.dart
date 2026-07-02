import '../../data/models/vibration_sample.dart';
import '../../data/models/location_sample.dart';

class RecordingReadinessChecklist {
  final bool isAuthenticated;
  final bool hasAccelerometerData;
  final bool hasGpsData;
  final bool isGpsAccuracyAcceptable;

  RecordingReadinessChecklist({
    required this.isAuthenticated,
    required this.hasAccelerometerData,
    required this.hasGpsData,
    required this.isGpsAccuracyAcceptable,
  });

  bool get isReady => 
      isAuthenticated && 
      hasAccelerometerData && 
      hasGpsData && 
      isGpsAccuracyAcceptable;
}

class RecordingValidator {
  static RecordingReadinessChecklist checkReadiness({
    required bool isAuthenticated,
    required VibrationSample? latestVibration,
    required LocationSample? latestLocation,
  }) {
    return RecordingReadinessChecklist(
      isAuthenticated: isAuthenticated,
      hasAccelerometerData: latestVibration != null,
      hasGpsData: latestLocation != null,
      isGpsAccuracyAcceptable: latestLocation != null && latestLocation.accuracy <= 25.0,
    );
  }
}
