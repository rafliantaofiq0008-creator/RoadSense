import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/vibration_calculator.dart';

void main() {
  group('VibrationCalculator', () {
    test('calculateMagnitude should return correct Euclidean distance', () {
      // 3-4-5 triangle logic
      // sqrt(3^2 + 4^2 + 0^2) = 5
      expect(VibrationCalculator.calculateMagnitude(3.0, 4.0, 0.0), equals(5.0));
      
      // sqrt(1^2 + 2^2 + 2^2) = sqrt(9) = 3
      expect(VibrationCalculator.calculateMagnitude(1.0, 2.0, 2.0), equals(3.0));
    });

    test('calculateRawVibration should return absolute difference from baseline', () {
      expect(VibrationCalculator.calculateRawVibration(10.0, 9.8), closeTo(0.2, 0.0001));
      expect(VibrationCalculator.calculateRawVibration(5.0, 9.8), closeTo(4.8, 0.0001));
      expect(VibrationCalculator.calculateRawVibration(9.8, 9.8), equals(0.0));
    });

    test('classifyPreviewStatus should classify correctly based on thresholds', () {
      expect(VibrationCalculator.classifyPreviewStatus(1.0), equals('smooth'));
      expect(VibrationCalculator.classifyPreviewStatus(1.49), equals('smooth'));
      
      expect(VibrationCalculator.classifyPreviewStatus(1.5), equals('bumpy'));
      expect(VibrationCalculator.classifyPreviewStatus(2.5), equals('bumpy'));
      
      expect(VibrationCalculator.classifyPreviewStatus(3.0), equals('high vibration'));
      expect(VibrationCalculator.classifyPreviewStatus(5.5), equals('high vibration'));
    });
  });
}
