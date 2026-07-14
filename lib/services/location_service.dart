import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/utils/location_calculator.dart';
import '../data/models/location_sample.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _fallbackPollTimer;
  final _locationStreamController = StreamController<LocationSample>.broadcast();

  LocationSample? _currentSample;
  DateTime? _lastSampleReceivedAt;

  Stream<LocationSample> get locationStream => _locationStreamController.stream;
  LocationSample? get currentSample => _currentSample;
  DateTime? get lastSampleReceivedAt => _lastSampleReceivedAt;
  bool get isRunning => _positionSubscription != null;

  /// Check and request location permissions
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
    }

    return true;
  }

  /// Start the location stream
  Future<void> startStream() async {
    if (_positionSubscription != null) {
      debugPrint('LocationService: Stream is already running.');
      return;
    }

    _currentSample = null;
    _lastSampleReceivedAt = null;

    try {
      await requestPermission();
    } catch (e) {
      debugPrint('LocationService Error: $e');
      rethrow;
    }

    LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true, // Forces hardware GPS instead of FusedLocationProvider (fixes issues on some devices)
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "RoadSense is actively tracking your trip to ensure high accuracy.",
          notificationTitle: "RoadSense Location Tracking",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _publishPosition(position);
      },
      onError: (error) {
        debugPrint('LocationService Stream Error: $error');
      },
    );

    _startFallbackPolling();

    // Fetch an initial position immediately so we don't have to wait for the first stream event
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 5),
        ),
      );
      _publishPosition(initialPos);
    } catch (e) {
      debugPrint('Failed to get initial current position: $e');
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _currentSample == null) {
          _publishPosition(lastKnown);
        }
      } catch (fallbackError) {
        debugPrint('Failed to get last known position: $fallbackError');
      }
    }
  }

  /// Stop the location stream
  void stopStream() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
    _lastSampleReceivedAt = null;
  }

  void dispose() {
    stopStream();
    _locationStreamController.close();
  }

  void _startFallbackPolling() {
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!isRunning) return;

      final lastReceivedAt = _lastSampleReceivedAt;
      final bool isStreamStale = lastReceivedAt == null ||
          DateTime.now().difference(lastReceivedAt) > const Duration(seconds: 3);

      if (!isStreamStale) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 4),
          ),
        );
        _publishPosition(position);
        debugPrint('LocationService: fallback polling emitted a fresh position.');
      } catch (e) {
        debugPrint('LocationService fallback polling failed: $e');
      }
    });
  }

  void _publishPosition(Position position) {
    final speedMps = position.speed >= 0 ? position.speed : 0.0;
    final speedKmh = LocationCalculator.metersPerSecondToKmh(speedMps);

    final sample = LocationSample(
      timestamp: position.timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
      speedMetersPerSecond: speedMps,
      speedKmh: speedKmh,
      accuracy: position.accuracy,
      altitude: position.altitude,
      heading: position.heading,
    );

    _currentSample = sample;
    _lastSampleReceivedAt = DateTime.now();
    _locationStreamController.add(sample);
  }
}
