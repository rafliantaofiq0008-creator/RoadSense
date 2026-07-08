import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/vibration_feature_extractor.dart';

void main() {
  group('VibrationFeatureExtractor Tests', () {
    late VibrationFeatureExtractor extractor;

    setUp(() {
      extractor = VibrationFeatureExtractor();
    });

    test('Isolates vertical acceleration and preserves sustained bump', () {
      final now = DateTime.now();
      
      // Simulate resting on desk (gravity on Z) for a few samples to stabilize
      for(int i=0; i<10; i++) {
        extractor.extractFeatures(0, 0, 9.81, now.add(Duration(milliseconds: i * 20)));
      }
      
      // Simulate sustained upward bump (15.0 on Z) for 100ms (5 samples at 50Hz)
      var features = extractor.extractFeatures(0, 0, 15.0, now.add(const Duration(milliseconds: 200)));
      for(int i=1; i<5; i++) {
         features = extractor.extractFeatures(0, 0, 15.0, now.add(Duration(milliseconds: 200 + (i * 20))));
      }
      
      // Dynamic Z builds up to around ~4.0 due to low pass filter
      expect(features.verticalPeak, greaterThan(3.0));
      expect(features.lateralPeak, lessThan(1.0));
      expect(features.isTurning, isFalse);
    });

    test('Detects turning motion over time', () {
      final now = DateTime.now();
      
      // Simulate resting on desk
      for(int i=0; i<10; i++) {
        extractor.extractFeatures(0, 0, 9.81, now.add(Duration(milliseconds: i * 20)));
      }
      
      // Simulate sharp turn (lateral X acceleration) for 5 samples
      var features = extractor.extractFeatures(5.0, 0, 9.81, now.add(const Duration(milliseconds: 200)));
      for(int i=1; i<5; i++) {
         features = extractor.extractFeatures(5.0, 0, 9.81, now.add(Duration(milliseconds: 200 + (i * 20))));
      }
      
      // Lateral peak builds up
      expect(features.lateralPeak, greaterThan(2.0));
      expect(features.isTurning, isTrue);
    });
  });
}
