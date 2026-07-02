class VibrationSample {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final double vibration;

  const VibrationSample({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.vibration,
  });
}
