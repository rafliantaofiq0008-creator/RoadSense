import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/utils/location_calculator.dart';
import '../data/models/location_sample.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _locationStreamController = StreamController<LocationSample>.broadcast();

  LocationSample? _currentSample;

  Stream<LocationSample> get locationStream => _locationStreamController.stream;
  LocationSample? get currentSample => _currentSample;
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

    try {
      await requestPermission();
    } catch (e) {
      debugPrint('LocationService Error: $e');
      rethrow;
    }

    LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
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
        _locationStreamController.add(sample);
      },
      onError: (error) {
        debugPrint('LocationService Stream Error: $error');
      },
    );
  }

  /// Stop the location stream
  void stopStream() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopStream();
    _locationStreamController.close();
  }
}
