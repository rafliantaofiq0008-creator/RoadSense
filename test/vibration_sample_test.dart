import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/data/models/vibration_sample.dart';

void main() {
  group('VibrationSample', () {
    test('Constructor should correctly initialize fields', () {
      final now = DateTime.now();
      final sample = VibrationSample(
        timestamp: now,
        x: 1.0,
        y: 2.0,
        z: 3.0,
        magnitude: 4.0,
        vibration: 5.0,
      );

      expect(sample.timestamp, equals(now));
      expect(sample.x, equals(1.0));
      expect(sample.y, equals(2.0));
      expect(sample.z, equals(3.0));
      expect(sample.magnitude, equals(4.0));
      expect(sample.vibration, equals(5.0));
    });
  });
}
