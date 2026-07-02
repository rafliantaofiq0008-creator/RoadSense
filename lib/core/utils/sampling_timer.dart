import 'dart:async';

/// A pure utility for running a periodic sampling callback.
class SamplingTimer {
  final Duration interval;
  final void Function() onTick;
  
  Timer? _timer;
  
  SamplingTimer({
    required this.interval,
    required this.onTick,
  });

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
