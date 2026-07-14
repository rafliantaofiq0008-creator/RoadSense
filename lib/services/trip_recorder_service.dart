import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config/tracking_sensitivity.dart';
import '../core/utils/trip_summary_calculator.dart';
import '../core/utils/app_date_time.dart';
import '../core/utils/recording_validator.dart';
import '../core/utils/sampling_timer.dart';
import '../data/remote/road_session_api.dart';
import '../data/remote/road_reading_api.dart';
import '../data/remote/road_event_api.dart';
import '../data/remote/road_segment_analysis_api.dart';
import '../data/models/location_sample.dart';
import '../data/models/road_reading.dart';
import '../data/models/road_session.dart';
import '../data/models/vibration_sample.dart';
import '../data/models/road_event.dart';
import '../data/models/pothole_detection_result.dart';
import '../core/services/movement_estimator.dart';
import '../core/services/road_segment_analyzer.dart';
import 'auth_service.dart';
import 'pothole_detection_service.dart';

class TripRecorderService extends ChangeNotifier {
  final RoadSessionApi _sessionApi = RoadSessionApi();
  final RoadReadingApi _readingApi = RoadReadingApi();
  final RoadEventApi _eventApi = RoadEventApi();
  final RoadSegmentAnalysisApi _segmentApi = RoadSegmentAnalysisApi();
  final AuthService _authService = AuthService();
  final PotholeDetectionService _detectionService = PotholeDetectionService();
  final MovementEstimator _movementEstimator = MovementEstimator();
  final RoadSegmentAnalyzer _segmentAnalyzer = RoadSegmentAnalyzer();
  TrackingSensitivityMode _sensitivityMode = TrackingSensitivityMode.car;

  bool _isRecording = false;
  String? _activeSessionId;

  // In-memory buffers
  final List<RoadReading> _readingsBuffer = [];
  final List<RoadEvent> _eventsBuffer = [];

  // Metrics
  int _uploadedReadingsCount = 0;
  int _uploadedEventsCount = 0;

  VibrationSample? _latestVibration;
  LocationSample? _latestLocation;
  
  SamplingTimer? _recordingTimer;
  SamplingTimer? _uploadTimer;
  String? _lastUploadError;

  bool get isRecording => _isRecording;
  String? get activeSessionId => _activeSessionId;
  String? get lastUploadError => _lastUploadError;
  int get bufferedReadingsCount => _readingsBuffer.length;
  int get uploadedReadingsCount => _uploadedReadingsCount;
  int get generatedReadingsCount => _readingsBuffer.length + _uploadedReadingsCount;
  int get bufferedEventsCount => _eventsBuffer.length;
  int get uploadedEventsCount => _uploadedEventsCount;
  int get generatedEventsCount => _eventsBuffer.length + _uploadedEventsCount;
  double get totalDistanceKm => _movementEstimator.totalDistanceM / 1000.0;
  double get currentSpeedKmh => _movementEstimator.smoothedSpeedKmh;
  RoadSegmentAnalyzer get segmentAnalyzer => _segmentAnalyzer;
  TrackingSensitivityMode get sensitivityMode => _sensitivityMode;
  TrackingSensitivityProfile get sensitivityProfile => TrackingSensitivityProfile.forMode(_sensitivityMode);

  PotholeDetectionResult? _latestEvent;
  PotholeDetectionResult? get latestEvent => _latestEvent;

  TripRecorderService() {
    final profile = sensitivityProfile;
    _movementEstimator.configureProfile(profile);
    _segmentAnalyzer.configureProfile(profile);
  }

  void resetMotionTracking() {
    _movementEstimator.reset();
    if (_latestLocation != null) {
      _latestLocation = _latestLocation!.copyWith(speedKmh: 0.0);
    }
  }

  void setSensitivityMode(TrackingSensitivityMode mode) {
    if (_sensitivityMode == mode) return;
    _sensitivityMode = mode;
    final profile = sensitivityProfile;
    _movementEstimator.configureProfile(profile);
    _segmentAnalyzer.configureProfile(profile);
    notifyListeners();
  }

  RecordingReadinessChecklist getRecordingReadiness() {
    bool isAuth = false;
    try {
      isAuth = _authService.getCurrentUserId().isNotEmpty;
    } catch (_) {}
    
    return RecordingValidator.checkReadiness(
      isAuthenticated: isAuth,
      latestVibration: _latestVibration,
      latestLocation: _latestLocation,
    );
  }

  /// Start trip session
  Future<void> startTrip({String? title}) async {
    if (_isRecording) return;
    
    final readiness = getRecordingReadiness();
    if (!readiness.isReady) {
      throw Exception('Recording readiness not met.');
    }
    
    final userId = _authService.getCurrentUserId();

    _activeSessionId = const Uuid().v4();
    _readingsBuffer.clear();
    _eventsBuffer.clear();
    _uploadedReadingsCount = 0;
    _uploadedEventsCount = 0;
    _latestEvent = null;
    // Do NOT clear _latestVibration and _latestLocation here, as they represent the current state
    // and we need them to start recording immediately without waiting for the next stream event.
    _movementEstimator.reset();
    _detectionService.reset();
    _segmentAnalyzer.reset();

    final session = RoadSession(
      id: _activeSessionId!,
      userId: userId,
      title: title ?? AppDateTime.autoTripTitle(),
      startTime: AppDateTime.nowUtc(),
      createdAt: AppDateTime.nowUtc(),
    );

    await _sessionApi.createSession(session);
    _isRecording = true;
    notifyListeners();

    // Start controlled recording interval (1 second)
    _recordingTimer?.stop();
    _recordingTimer = SamplingTimer(interval: const Duration(seconds: 1), onTick: _combineReading);
    _recordingTimer?.start();

    // Start upload interval (e.g., every 5 seconds)
    _uploadTimer?.stop();
    _uploadTimer = SamplingTimer(interval: const Duration(seconds: 5), onTick: flushNow);
    _uploadTimer?.start();
  }

  /// Stop trip session
  Future<void> stopTrip() async {
    if (!_isRecording || _activeSessionId == null) return;

    _recordingTimer?.stop();
    _recordingTimer = null;
    _uploadTimer?.stop();
    _uploadTimer = null;

    final sessionId = _activeSessionId!;
    
    // Flush remaining buffer
    await flushNow();

    // Upload segments
    _segmentAnalyzer.finalizeTrip(_authService.getCurrentUserId(), sessionId, _movementEstimator.totalDistanceM);
    final segments = _segmentAnalyzer.finalizeSegments();
    if (segments.isNotEmpty) {
      await _segmentApi.insertSegments(segments);
    }

    if (_uploadedReadingsCount == 0 && _uploadedEventsCount == 0) {
      // Empty session, delete it from Supabase
      try {
        await _sessionApi.deleteSession(sessionId);
      } catch (e) {
        debugPrint('TripRecorderService Error deleting empty session: $e');
      }
    } else {
      // Update summary
      await _updateSummary(sessionId);
    }

    _isRecording = false;
    _activeSessionId = null;
    _latestVibration = null;
    _latestLocation = null;
    _movementEstimator.reset();
    _detectionService.reset();
    _segmentAnalyzer.reset();
    notifyListeners();
  }

  void updateLatestVibration(VibrationSample sample) {
    _latestVibration = sample;

    if (_isRecording && _activeSessionId != null) {
      final result = _detectionService.processSensorData(sample, _latestLocation);
      if (result != null) {
        _latestEvent = result;
        _bufferRoadEvent(result);
        _segmentAnalyzer.processData(
          userId: _authService.getCurrentUserId(),
          sessionId: _activeSessionId!,
          location: null,
          vibration: null,
          event: result,
          totalDistanceM: _movementEstimator.totalDistanceM,
        );
      }
    }
  }

  void updateLatestLocation(LocationSample sample) {
    _latestLocation = _movementEstimator.processLocation(sample);
  }

  void _bufferRoadEvent(PotholeDetectionResult result) {
    if (!_isRecording || _activeSessionId == null) return;
    final userId = _authService.getCurrentUserId();
    final event = RoadEvent(
      id: const Uuid().v4(),
      sessionId: _activeSessionId!,
      userId: userId,
      eventType: result.eventType,
      severity: result.severity,
      magnitude: result.magnitude,
      vibration: result.vibration,
      speed: result.speed,
      latitude: result.latitude,
      longitude: result.longitude,
      gpsAccuracy: result.gpsAccuracy,
      recordedAt: result.timestamp,
      confidenceScore: result.confidenceScore,
      verticalPeak: result.verticalPeak,
      lateralPeak: result.lateralPeak,
      jerkPeak: result.jerkPeak,
      validationStatus: result.validationStatus,
      rejectionReason: result.rejectionReason,
    );
    
    if (result.validationStatus == 'valid') {
      _eventsBuffer.add(event);
    }
  }

  void _combineReading() {
    if (!_isRecording || _activeSessionId == null) return;
    if (_latestVibration == null || _latestLocation == null) return;
    
    final vib = _latestVibration!;
    final loc = _latestLocation!;

    if (loc.accuracy > 25.0) return;

    final userId = _authService.getCurrentUserId();

    final reading = RoadReading(
      id: const Uuid().v4(),
      sessionId: _activeSessionId!,
      userId: userId,
      accelerationX: vib.x,
      accelerationY: vib.y,
      accelerationZ: vib.z,
      magnitude: vib.magnitude,
      vibration: vib.vibration,
      speed: loc.speedKmh,
      latitude: loc.latitude,
      longitude: loc.longitude,
      gpsAccuracy: loc.accuracy,
      recordedAt: AppDateTime.nowUtc(),
    );

    _segmentAnalyzer.processData(
      userId: userId,
      sessionId: _activeSessionId!,
      location: loc,
      vibration: vib,
      event: null,
      totalDistanceM: _movementEstimator.totalDistanceM,
    );

    _readingsBuffer.add(reading);

    if (_readingsBuffer.length >= 25 || _eventsBuffer.length >= 25) {
      flushNow();
    }
  }

  Future<void> flushNow() async {
    if (_readingsBuffer.isEmpty && _eventsBuffer.isEmpty) return;

    final readingsToUpload = List<RoadReading>.from(_readingsBuffer);
    final eventsToUpload = List<RoadEvent>.from(_eventsBuffer);

    try {
      if (readingsToUpload.isNotEmpty) {
        await _readingApi.upsertReadingsBatch(readingsToUpload);
        _uploadedReadingsCount += readingsToUpload.length;
        _readingsBuffer.removeWhere((r) => readingsToUpload.contains(r));
      }

      if (eventsToUpload.isNotEmpty) {
        await _eventApi.upsertEventsBatch(eventsToUpload);
        _uploadedEventsCount += eventsToUpload.length;
        _eventsBuffer.removeWhere((e) => eventsToUpload.contains(e));
      }
      _lastUploadError = null;
    } catch (e) {
      debugPrint('TripRecorderService Error uploading batch: $e');
      _lastUploadError = e.toString();
    }
  }

  Future<void> _updateSummary(String sessionId) async {
    try {
      final session = await _sessionApi.getSessionById(sessionId);
      if (session == null) return;

      final readings = await _readingApi.getReadingsBySessionId(sessionId);
      final events = await _eventApi.getEventsBySessionId(sessionId);
      
      var updatedSession = TripSummaryCalculator.calculateSummary(
        session.copyWith(
          endTime: AppDateTime.nowUtc(),
          totalEvents: events.length,
        ),
        readings,
      );
      
      updatedSession = updatedSession.copyWith(
        estimatedDistanceKm: _movementEstimator.totalDistanceM / 1000.0,
      );

      await _sessionApi.updateSessionSummary(updatedSession);
    } catch (e) {
      debugPrint('TripRecorderService Error updating summary: $e');
    }
  }

  @override
  void dispose() {
    _recordingTimer?.stop();
    _uploadTimer?.stop();
    super.dispose();
  }
}
