import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/utils/sampling_timer.dart';

void main() {
  group('SamplingTimer Tests', () {
    test('start initiates the timer and stop cancels it', () async {
      int tickCount = 0;
      final timer = SamplingTimer(
        interval: const Duration(milliseconds: 50),
        onTick: () => tickCount++,
      );

      expect(timer.isRunning, isFalse);

      timer.start();
      expect(timer.isRunning, isTrue);

      await Future.delayed(const Duration(milliseconds: 175));
      timer.stop();
      expect(timer.isRunning, isFalse);

      final countAfterStop = tickCount;
      expect(countAfterStop, greaterThanOrEqualTo(3));
      
      await Future.delayed(const Duration(milliseconds: 100));
      expect(tickCount, equals(countAfterStop)); // Should not have ticked after stop
    });

    test('start does not create multiple timers if already running', () async {
      int tickCount = 0;
      final timer = SamplingTimer(
        interval: const Duration(milliseconds: 50),
        onTick: () => tickCount++,
      );

      timer.start();
      timer.start(); // Should be ignored

      await Future.delayed(const Duration(milliseconds: 125));
      timer.stop();

      // If it created two timers, tickCount would be double
      expect(tickCount, lessThanOrEqualTo(3));
    });
  });
}
