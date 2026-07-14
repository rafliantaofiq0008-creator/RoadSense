import 'dart:math';
import '../config/tracking_sensitivity.dart';
import '../../data/models/location_sample.dart';
import '../../data/models/pothole_detection_result.dart';
import '../../data/models/road_segment_analysis.dart';
import '../../data/models/vibration_sample.dart';

class RoadSegmentAnalyzer {
  final double segmentSizeM = 100.0;
  TrackingSensitivityProfile _profile = TrackingSensitivityProfile.car;
  
  // Current segment state
  int _currentSegmentIndex = 0;
  double _segmentStartDistanceM = 0.0;
  
  final List<LocationSample> _segmentLocations = [];
  final List<VibrationSample> _segmentVibrations = [];
  final List<PotholeDetectionResult> _segmentEvents = [];

  // Completed segments
  final List<RoadSegmentAnalysis> _completedSegments = [];

  List<RoadSegmentAnalysis> get completedSegments => _completedSegments;
  TrackingSensitivityProfile get profile => _profile;

  void configureProfile(TrackingSensitivityProfile profile) {
    _profile = profile;
  }
  
  void reset() {
    _currentSegmentIndex = 0;
    _segmentStartDistanceM = 0.0;
    _segmentLocations.clear();
    _segmentVibrations.clear();
    _segmentEvents.clear();
    _completedSegments.clear();
  }
  
  List<RoadSegmentAnalysis> finalizeSegments() {
    // Return a copy and clear the buffer
    final copy = List<RoadSegmentAnalysis>.from(_completedSegments);
    return copy;
  }
  
  /// Processes a new tick of data. 
  /// Uses totalDistanceM to determine if we crossed the 100m boundary.
  void processData({
    required double totalDistanceM,
    required String userId,
    required String sessionId,
    LocationSample? location,
    VibrationSample? vibration,
    PotholeDetectionResult? event,
  }) {
    if (location != null) _segmentLocations.add(location);
    if (vibration != null) _segmentVibrations.add(vibration);
    if (event != null && event.validationStatus == 'valid') {
      _segmentEvents.add(event);
    }

    // Check boundary
    double currentSegmentLength = totalDistanceM - _segmentStartDistanceM;
    if (currentSegmentLength >= segmentSizeM) {
      _finalizeSegment(userId, sessionId, totalDistanceM);
    }
  }
  
  /// Finalizes whatever is currently in the buffer (used at end of trip)
  void finalizeTrip(String userId, String sessionId, double finalDistanceM) {
    if (_segmentLocations.isNotEmpty || _segmentVibrations.isNotEmpty) {
      _finalizeSegment(userId, sessionId, finalDistanceM);
    }
  }

  void _finalizeSegment(String userId, String sessionId, double endDistanceM) {
    final analysis = buildSegmentAnalysis(
      segmentIndex: _currentSegmentIndex,
      startDistanceM: _segmentStartDistanceM,
      endDistanceM: endDistanceM,
      locations: _segmentLocations,
      vibrations: _segmentVibrations,
      events: _segmentEvents,
      profile: _profile,
      userId: userId,
      sessionId: sessionId,
    );

    _completedSegments.add(analysis);

    // Reset for next segment
    _currentSegmentIndex++;
    _segmentStartDistanceM = endDistanceM;
    _segmentLocations.clear();
    _segmentVibrations.clear();
    _segmentEvents.clear();
  }

  RoadSegmentAnalysis getLiveCandidate(double currentTotalDistanceM) {
    return buildSegmentAnalysis(
      segmentIndex: _currentSegmentIndex,
      startDistanceM: _segmentStartDistanceM,
      endDistanceM: currentTotalDistanceM,
      locations: _segmentLocations,
      vibrations: _segmentVibrations,
      events: _segmentEvents,
      profile: _profile,
      userId: '',
      sessionId: '',
    );
  }

  static RoadSegmentAnalysis buildSegmentAnalysis({
    required int segmentIndex,
    required double startDistanceM,
    required double endDistanceM,
    required List<LocationSample> locations,
    required List<VibrationSample> vibrations,
    required List<PotholeDetectionResult> events,
    TrackingSensitivityProfile profile = TrackingSensitivityProfile.car,
    required String userId,
    required String sessionId,
  }) {
    final segmentLengthM = endDistanceM - startDistanceM;
    final readingsCount = vibrations.length;
    
    double avgSpeed = 0;
    double maxSpeed = 0;
    double avgGpsAccuracy = 0;
    
    if (locations.isNotEmpty) {
      double sumSpeed = locations.map((l) => l.speedKmh).reduce((a, b) => a + b);
      avgSpeed = sumSpeed / locations.length;
      maxSpeed = locations.map((l) => l.speedKmh).reduce((a, b) => max(a, b));
      double sumGps = locations.map((l) => l.accuracy).reduce((a, b) => a + b);
      avgGpsAccuracy = sumGps / locations.length;
    }

    double avgVibration = 0.0;
    double maxVibration = 0.0;
    double maxVerticalPeak = 0;
    double maxJerk = 0;
    double maxLateral = 0;

    if (vibrations.isNotEmpty) {
      double sumVib = vibrations.map((v) => v.vibration).reduce((a, b) => a + b);
      avgVibration = sumVib / vibrations.length;
      maxVibration = vibrations.map((v) => v.vibration).reduce((a, b) => max(a, b));
    }
    
    // We don't store raw vertical peak in VibrationSample currently, but we do in PotholeDetectionResult
    // Actually we should infer it from events if present, or just use maxVibration for rough estimate.
    if (events.isNotEmpty) {
      final vPeaks = events.where((e) => e.verticalPeak != null).map((e) => e.verticalPeak!).toList();
      if (vPeaks.isNotEmpty) maxVerticalPeak = vPeaks.reduce((a, b) => max(a, b));
      
      final jPeaks = events.where((e) => e.jerkPeak != null).map((e) => e.jerkPeak!).toList();
      if (jPeaks.isNotEmpty) maxJerk = jPeaks.reduce((a, b) => max(a, b));
      
      final lPeaks = events.where((e) => e.lateralPeak != null).map((e) => e.lateralPeak!).toList();
      if (lPeaks.isNotEmpty) maxLateral = lPeaks.reduce((a, b) => max(a, b));
    }

    int potholeCount = events.where((e) => e.severity == 'pothole').length;
    int severeCount = events.where((e) => e.severity == 'severe_pothole').length;
    int damagedCount = events.where((e) => e.severity == 'damaged').length;
    
    String roadCondition = 'not_assessed';
    double? score;
    String? recommendation;
    String confidence = 'low';

    // Core Logic Rules
    if (segmentLengthM < profile.segmentMinAssessmentDistanceM ||
        avgSpeed < profile.segmentMinAssessmentSpeedKmh) {
      roadCondition = 'not_assessed';
      score = null;
      recommendation = 'Survei ulang dengan jarak dan kecepatan memadai';
      confidence = 'low';
    } else {
      confidence = (avgGpsAccuracy <= 15) ? 'high' : (avgGpsAccuracy <= 25 ? 'medium' : 'low');
      
      if (severeCount >= 1) {
        roadCondition = 'severe_damage';
        score = 85.0 + min(15.0, severeCount * 5.0); // 85-100
        recommendation = 'Prioritas perbaikan dan pemasangan peringatan sementara';
      } else if (potholeCount >= 1) {
        roadCondition = 'pothole_indication';
        score = 65.0 + min(15.0, potholeCount * 5.0); // 65-80
        recommendation = 'Verifikasi lapangan dan patching lokal';
      } else if (damagedCount >= 2 || (maxVerticalPeak > 5.0 && events.length >= 2)) {
        roadCondition = 'uneven_road';
        score = 45.0 + min(15.0, damagedCount * 5.0); // 45-60
        recommendation = 'Inspeksi visual dan perataan permukaan';
      } else if (damagedCount == 1 || maxVibration > 3.0) {
        roadCondition = 'slightly_uneven';
        score = 30.0;
        recommendation = 'Monitoring berkala (indikasi awal)';
      } else {
        roadCondition = 'good';
        score = 20.0;
        recommendation = 'Monitoring berkala';
      }
    }

    return RoadSegmentAnalysis(
      userId: userId,
      sessionId: sessionId,
      segmentIndex: segmentIndex,
      distanceStartM: startDistanceM,
      distanceEndM: endDistanceM,
      segmentLengthM: segmentLengthM,
      readingsCount: readingsCount,
      avgSpeedKmh: avgSpeed,
      maxSpeedKmh: maxSpeed,
      avgVibration: avgVibration,
      maxVibration: maxVibration,
      verticalPeak: maxVerticalPeak,
      jerkPeak: maxJerk,
      lateralPeak: maxLateral,
      gpsAccuracyAvg: avgGpsAccuracy,
      eventCount: events.length,
      potholeCount: potholeCount,
      severePotholeCount: severeCount,
      speedBumpCount: 0,
      dataConfidenceLevel: confidence,
      roadCondition: roadCondition,
      conditionScore: score,
      recommendation: recommendation,
    );
  }
}
