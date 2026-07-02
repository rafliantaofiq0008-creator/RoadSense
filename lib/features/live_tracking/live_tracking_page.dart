import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/vibration_calculator.dart';
import '../../core/utils/location_calculator.dart';
import '../../data/models/vibration_sample.dart';
import '../../data/models/location_sample.dart';
import '../../services/accelerometer_service.dart';
import '../../services/location_service.dart';
import '../../services/trip_recorder_service.dart';

import '../../shared/charts/vibration_chart.dart';

class LiveTrackingPage extends StatefulWidget {
  const LiveTrackingPage({super.key});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  final AccelerometerService _accelerometerService = AccelerometerService();
  final LocationService _locationService = LocationService();
  final TripRecorderService _tripRecorderService = TripRecorderService();
  
  StreamSubscription<VibrationSample>? _accelSub;
  StreamSubscription<LocationSample>? _locSub;
  
  final List<VibrationSample> _samples = [];
  static const int _maxSamples = 50;
  
  bool _isRunning = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _accelSub?.cancel();
    _locSub?.cancel();
    _accelerometerService.dispose();
    _locationService.dispose();
    _tripRecorderService.dispose();
    super.dispose();
  }

  Future<void> _startPreview() async {
    if (_isRunning || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Start GPS
      await _locationService.startStream();
      _locSub = _locationService.locationStream.listen((sample) {
        if (mounted) {
          _tripRecorderService.updateLatestLocation(sample);
          setState(() {});
        }
      });

      // Start Accelerometer
      _accelerometerService.startStream();
      _accelSub = _accelerometerService.vibrationStream.listen((sample) {
        if (mounted) {
          _tripRecorderService.updateLatestVibration(sample);
          setState(() {
            _samples.add(sample);
            if (_samples.length > _maxSamples) {
              _samples.removeAt(0);
            }
          });
        }
      });

      setState(() => _isRunning = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _stopPreview() async {
    if (_tripRecorderService.isRecording) {
      await _stopRecording();
    }
    
    _accelerometerService.stopStream();
    _locationService.stopStream();
    
    _accelSub?.cancel();
    _locSub?.cancel();
    
    _accelSub = null;
    _locSub = null;
    
    setState(() => _isRunning = false);
  }

  void _resetBaseline() {
    _accelerometerService.resetBaseline();
  }

  Future<void> _startRecording() async {
    if (!_isRunning) {
      await _startPreview();
    }
    try {
      await _tripRecorderService.startTrip();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _tripRecorderService.stopTrip();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip saved to Cloud.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibSample = _accelerometerService.currentSample;
    final locSample = _locationService.currentSample;

    // Vibration status
    final roadStatus = vibSample != null 
        ? VibrationCalculator.classifyPreviewStatus(vibSample.vibration) 
        : 'Unknown';
    Color roadStatusColor = Colors.grey;
    if (roadStatus == 'smooth') roadStatusColor = Colors.green;
    if (roadStatus == 'bumpy') roadStatusColor = Colors.orange;
    if (roadStatus == 'high vibration') roadStatusColor = Colors.red;

    // GPS status
    final isMoving = locSample != null 
        ? LocationCalculator.isMoving(locSample.speedKmh)
        : false;
    final gpsQuality = locSample != null 
        ? (LocationCalculator.isGpsAccuracyAcceptable(locSample.accuracy) ? 'Good' : 'Poor')
        : 'Unknown';
    final gpsColor = gpsQuality == 'Good' ? Colors.green : (gpsQuality == 'Poor' ? Colors.orange : Colors.grey);

    String noticeText = 'Preview mode only. Press Start Recording to upload valid trip data to Supabase.';
    Color noticeColor = Colors.blue;
    if (_tripRecorderService.isRecording) {
      noticeText = 'Recording to Cloud.\n'
          'Readings: ${_tripRecorderService.generatedReadingsCount} total (${_tripRecorderService.bufferedReadingsCount} buf / ${_tripRecorderService.uploadedReadingsCount} up)\n'
          'Events: ${_tripRecorderService.generatedEventsCount} total (${_tripRecorderService.bufferedEventsCount} buf / ${_tripRecorderService.uploadedEventsCount} up)';
      if (_tripRecorderService.lastUploadError != null) {
        noticeText += '\nUpload Error: ${_tripRecorderService.lastUploadError}';
      }
      noticeColor = Colors.red;
    } else if (_tripRecorderService.activeSessionId == null && _tripRecorderService.uploadedReadingsCount > 0) {
      noticeText = 'Recording stopped. Trip saved to Cloud.';
      noticeColor = Colors.green;
    }

    final readiness = _tripRecorderService.getRecordingReadiness();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking (Preview)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: noticeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: noticeColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(_tripRecorderService.isRecording ? Icons.fiber_manual_record : Icons.info_outline, color: noticeColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          noticeText,
                          style: TextStyle(color: noticeColor, fontWeight: FontWeight.bold),
                        ),
                        if (_tripRecorderService.isRecording && _tripRecorderService.activeSessionId != null)
                          Text(
                            'Session ID: ${_tripRecorderService.activeSessionId!.substring(0, 8)}...',
                            style: TextStyle(color: noticeColor, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // GPS Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('GPS Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildValueCard('Lat', locSample?.latitude),
                                _buildValueCard('Lng', locSample?.longitude),
                                _buildValueCard('Acc (m)', locSample?.accuracy),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildValueCard('Speed (km/h)', locSample?.speedKmh),
                                _buildTextCard('Movement', isMoving ? 'Moving' : 'Stopped', isMoving ? Colors.green : Colors.grey),
                                _buildTextCard('Quality', gpsQuality, gpsColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Detection Status Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Detection Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  _tripRecorderService.isRecording ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: _tripRecorderService.isRecording ? Colors.green : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            if (!_tripRecorderService.isRecording)
                              const Text('Pothole detection runs only while cloud trip recording is active.', style: TextStyle(color: Colors.grey)),
                            if (_tripRecorderService.isRecording && gpsQuality == 'Poor')
                              const Text('GPS accuracy is poor. Events will not be saved.', style: TextStyle(color: Colors.orange)),
                            if (_tripRecorderService.isRecording && gpsQuality != 'Poor') ...[
                              Text('Events: ${_tripRecorderService.generatedEventsCount} total (${_tripRecorderService.bufferedEventsCount} buf / ${_tripRecorderService.uploadedEventsCount} up)', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (_tripRecorderService.latestEvent != null) ...[
                                Text('Latest Event: ${_tripRecorderService.latestEvent!.eventType} (${_tripRecorderService.latestEvent!.severity})'),
                                Text('Vibration: ${_tripRecorderService.latestEvent!.vibration.toStringAsFixed(2)}'),
                                Text('Speed: ${_tripRecorderService.latestEvent!.speed.toStringAsFixed(1)} km/h'),
                                ] else
                                  const Text('No events detected yet.', style: TextStyle(color: Colors.grey)),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Readiness Section
                      if (!_tripRecorderService.isRecording)
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Recording Readiness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                _buildChecklistItem('Authenticated User', readiness.isAuthenticated),
                                _buildChecklistItem('Accelerometer Data Available', readiness.hasAccelerometerData),
                                _buildChecklistItem('GPS Data Available', readiness.hasGpsData),
                                _buildChecklistItem('GPS Accuracy Acceptable (<25m)', readiness.isGpsAccuracyAcceptable),
                                if (kIsWeb) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Warning: Web preview is limited. Real accelerometer and road vibration testing require an Android device.',
                                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      if (!_tripRecorderService.isRecording)
                        const SizedBox(height: 16),

                    // Accelerometer Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Accelerometer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildValueCard('X', vibSample?.x),
                                _buildValueCard('Y', vibSample?.y),
                                _buildValueCard('Z', vibSample?.z),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildValueCard('Magnitude', vibSample?.magnitude),
                                _buildValueCard('Vibration', vibSample?.vibration),
                                _buildTextCard('Status', roadStatus.toUpperCase(), roadStatusColor),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 150,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: VibrationChart(samples: _samples),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_tripRecorderService.isRecording)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : (_isRunning ? _stopPreview : _startPreview),
                    icon: _isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(_isRunning ? 'Stop Preview' : 'Start Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.grey.shade200 : Colors.green.shade100,
                      foregroundColor: _isRunning ? Colors.grey.shade900 : Colors.green.shade900,
                    ),
                  ),
                if (!_tripRecorderService.isRecording)
                  ElevatedButton.icon(
                    onPressed: (_isLoading || !readiness.isReady) ? null : _startRecording,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Start Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                    ),
                  ),
                if (_tripRecorderService.isRecording)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _isRunning ? _resetBaseline : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueCard(String label, double? value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value != null ? value.toStringAsFixed(2) : '--',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTextCard(String label, String text, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String text, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle : Icons.cancel,
            color: isChecked ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[800])),
        ],
      ),
    );
  }
}
