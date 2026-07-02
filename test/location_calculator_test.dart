import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/location_calculator.dart';

void main() {
  group('LocationCalculator', () {
    test('metersPerSecondToKmh should multiply by 3.6', () {
      expect(LocationCalculator.metersPerSecondToKmh(1.0), closeTo(3.6, 0.0001));
      expect(LocationCalculator.metersPerSecondToKmh(10.0), closeTo(36.0, 0.0001));
      expect(LocationCalculator.metersPerSecondToKmh(0.0), equals(0.0));
    });

    test('isMoving should return true only if speed is >= 5.0 km/h', () {
      expect(LocationCalculator.isMoving(0.0), isFalse);
      expect(LocationCalculator.isMoving(4.9), isFalse);
      expect(LocationCalculator.isMoving(5.0), isTrue);
      expect(LocationCalculator.isMoving(60.0), isTrue);
    });

    test('isGpsAccuracyAcceptable should return true only if accuracy <= 25.0', () {
      expect(LocationCalculator.isGpsAccuracyAcceptable(5.0), isTrue);
      expect(LocationCalculator.isGpsAccuracyAcceptable(25.0), isTrue);
      expect(LocationCalculator.isGpsAccuracyAcceptable(25.1), isFalse);
      expect(LocationCalculator.isGpsAccuracyAcceptable(100.0), isFalse);
    });
  });
}
