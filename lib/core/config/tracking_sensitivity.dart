enum TrackingSensitivityMode {
  walking,
  slowMotorcycle,
  car,
}

class TrackingSensitivityProfile {
  final TrackingSensitivityMode mode;
  final String label;
  final String helperText;
  final double minCoordinateStepM;
  final double maxNoiseGateM;
  final double minMovementSpeedKmh;
  final Duration maxCandidateWindow;
  final double previewMovingThresholdKmh;
  final double segmentMinAssessmentSpeedKmh;
  final double segmentMinAssessmentDistanceM;

  const TrackingSensitivityProfile({
    required this.mode,
    required this.label,
    required this.helperText,
    required this.minCoordinateStepM,
    required this.maxNoiseGateM,
    required this.minMovementSpeedKmh,
    required this.maxCandidateWindow,
    required this.previewMovingThresholdKmh,
    required this.segmentMinAssessmentSpeedKmh,
    required this.segmentMinAssessmentDistanceM,
  });

  static const TrackingSensitivityProfile walking = TrackingSensitivityProfile(
    mode: TrackingSensitivityMode.walking,
    label: 'Jalan Kaki',
    helperText: 'Lebih sensitif untuk langkah kecil dan lari pelan.',
    minCoordinateStepM: 0.12,
    maxNoiseGateM: 1.2,
    minMovementSpeedKmh: 0.15,
    maxCandidateWindow: Duration(seconds: 6),
    previewMovingThresholdKmh: 0.6,
    segmentMinAssessmentSpeedKmh: 1.0,
    segmentMinAssessmentDistanceM: 15.0,
  );

  static const TrackingSensitivityProfile slowMotorcycle = TrackingSensitivityProfile(
    mode: TrackingSensitivityMode.slowMotorcycle,
    label: 'Motor Pelan',
    helperText: 'Seimbang untuk stop-and-go dan kecepatan rendah.',
    minCoordinateStepM: 0.2,
    maxNoiseGateM: 2.0,
    minMovementSpeedKmh: 0.2,
    maxCandidateWindow: Duration(seconds: 5),
    previewMovingThresholdKmh: 2.0,
    segmentMinAssessmentSpeedKmh: 2.5,
    segmentMinAssessmentDistanceM: 25.0,
  );

  static const TrackingSensitivityProfile car = TrackingSensitivityProfile(
    mode: TrackingSensitivityMode.car,
    label: 'Mobil',
    helperText: 'Default untuk perjalanan normal dengan filter noise lebih ketat.',
    minCoordinateStepM: 0.3,
    maxNoiseGateM: 3.0,
    minMovementSpeedKmh: 0.3,
    maxCandidateWindow: Duration(seconds: 4),
    previewMovingThresholdKmh: 5.0,
    segmentMinAssessmentSpeedKmh: 5.0,
    segmentMinAssessmentDistanceM: 50.0,
  );

  static const List<TrackingSensitivityProfile> all = [
    walking,
    slowMotorcycle,
    car,
  ];

  static TrackingSensitivityProfile forMode(TrackingSensitivityMode mode) {
    switch (mode) {
      case TrackingSensitivityMode.walking:
        return walking;
      case TrackingSensitivityMode.slowMotorcycle:
        return slowMotorcycle;
      case TrackingSensitivityMode.car:
        return car;
    }
  }
}
