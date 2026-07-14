import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/tracking_sensitivity.dart';
import '../../core/utils/vibration_calculator.dart';
import '../../core/utils/location_calculator.dart';
import '../../core/utils/recording_validator.dart';
import '../../data/models/vibration_sample.dart';
import '../../data/models/location_sample.dart';
import '../../services/accelerometer_service.dart';
import '../../services/location_service.dart';
import '../../services/trip_recorder_service.dart';

import '../../shared/charts/vibration_chart.dart';
import '../../shared/widgets/app_surface_card.dart';
import '../../shared/widgets/status_badge.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../data/remote/road_photo_api.dart';
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
  static const int _maxSamples = 36;
  static const Duration _uiRefreshInterval = Duration(milliseconds: 220);
  
  bool _isRunning = false;
  bool _isLoading = false;
  Timer? _uiRefreshTimer;
  DateTime? _lastUiRefreshAt;

  final RoadPhotoApi _photoApi = RoadPhotoApi();
  final ImagePicker _picker = ImagePicker();
  int _sessionPhotoCount = 0;
  bool _isUploadingPhoto = false;

  void _handleSensitivityChanged(TrackingSensitivityMode mode) {
    _tripRecorderService.setSensitivityMode(mode);

    if (_isRunning) {
      _tripRecorderService.resetMotionTracking();
      final currentLocation = _locationService.currentSample;
      if (currentLocation != null) {
        _tripRecorderService.updateLatestLocation(currentLocation);
      }
    }

    setState(() {});
  }

  Future<void> _takePhoto() async {
    final sessionId = _tripRecorderService.activeSessionId;
    if (sessionId == null || !_tripRecorderService.isRecording) return;

    try {
      final XFile? xfile = await _picker.pickImage(source: ImageSource.camera);
      if (xfile == null) return;

      setState(() => _isUploadingPhoto = true);

      // Simple compression
      final File file = File(xfile.path);
      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        final resizedImage = img.copyResize(decodedImage, width: 800);
        await file.writeAsBytes(img.encodeJpg(resizedImage, quality: 70));
      }

      final locSample = _locationService.currentSample;
      final vibSample = _accelerometerService.currentSample;

      await _photoApi.uploadPhotoForSession(
        sessionId: sessionId,
        imageFile: file,
        caption: 'Manual road condition photo',
        latitude: locSample?.latitude,
        longitude: locSample?.longitude,
        gpsAccuracy: locSample?.accuracy,
        speed: locSample?.speedKmh,
        vibration: vibSample?.vibration,
      );

      if (mounted) {
        setState(() => _sessionPhotoCount++);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _locSub?.cancel();
    _uiRefreshTimer?.cancel();
    _accelerometerService.dispose();
    _locationService.dispose();
    _tripRecorderService.dispose();
    super.dispose();
  }

  void _requestUiRefresh({bool immediate = false}) {
    if (!mounted) return;

    if (immediate) {
      _uiRefreshTimer?.cancel();
      _uiRefreshTimer = null;
      _lastUiRefreshAt = DateTime.now();
      setState(() {});
      return;
    }

    final now = DateTime.now();
    final shouldRefreshNow = _lastUiRefreshAt == null ||
        now.difference(_lastUiRefreshAt!) >= _uiRefreshInterval;

    if (shouldRefreshNow) {
      _lastUiRefreshAt = now;
      setState(() {});
      return;
    }

    if (_uiRefreshTimer != null) return;

    final remaining = _uiRefreshInterval - now.difference(_lastUiRefreshAt!);
    _uiRefreshTimer = Timer(remaining, () {
      _uiRefreshTimer = null;
      if (!mounted) return;
      _lastUiRefreshAt = DateTime.now();
      setState(() {});
    });
  }

  Future<void> _startPreview() async {
    if (_isRunning || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      _tripRecorderService.resetMotionTracking();

      // Start GPS
      await _locationService.startStream();
      
      if (_locationService.currentSample != null) {
        _tripRecorderService.updateLatestLocation(_locationService.currentSample!);
      }
      
      _locSub = _locationService.locationStream.listen((sample) {
        if (mounted) {
          _tripRecorderService.updateLatestLocation(sample);
          _requestUiRefresh();
        }
      });

      // Start Accelerometer
      _accelerometerService.startStream();
      _accelSub = _accelerometerService.vibrationStream.listen((sample) {
        if (mounted) {
          _tripRecorderService.updateLatestVibration(sample);
          _samples.add(sample);
          if (_samples.length > _maxSamples) {
            _samples.removeAt(0);
          }
          _requestUiRefresh();
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
    _tripRecorderService.resetMotionTracking();
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;
    _lastUiRefreshAt = null;
    
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
    final theme = Theme.of(context);
    final vibSample = _accelerometerService.currentSample;
    final locSample = _locationService.currentSample;
    final lastGpsUpdateAt = _locationService.lastSampleReceivedAt;
    final gpsUpdateAge = lastGpsUpdateAt == null
        ? null
        : DateTime.now().difference(lastGpsUpdateAt);

    // Vibration status
    final roadStatus = vibSample != null 
        ? VibrationCalculator.classifyPreviewStatus(vibSample.vibration) 
        : 'Unknown';
    Color roadStatusColor = Colors.grey;
    if (roadStatus == 'smooth') roadStatusColor = Colors.green;
    if (roadStatus == 'bumpy') roadStatusColor = Colors.orange;
    if (roadStatus == 'high vibration') roadStatusColor = Colors.red;

    // GPS status
    final sensitivityProfile = _tripRecorderService.sensitivityProfile;
    final previewSpeedKmh = _tripRecorderService.currentSpeedKmh;
    final isMoving = locSample != null 
        ? LocationCalculator.isMoving(
            previewSpeedKmh,
            thresholdKmh: sensitivityProfile.previewMovingThresholdKmh,
          )
        : false;
    final gpsQuality = locSample != null 
        ? (LocationCalculator.isGpsAccuracyAcceptable(locSample.accuracy) ? 'Good' : 'Poor')
        : 'Unknown';
    final gpsColor = gpsQuality == 'Good' ? Colors.green : (gpsQuality == 'Poor' ? Colors.orange : Colors.grey);
    final totalDistanceM = _tripRecorderService.totalDistanceKm * 1000.0;
    final activeSegment = _tripRecorderService.segmentAnalyzer.getLiveCandidate(totalDistanceM);
    final segmentProgressM = activeSegment.distanceEndM - activeSegment.distanceStartM;
    final segmentTargetM = _tripRecorderService.segmentAnalyzer.segmentSizeM;
    final segmentProgress = segmentTargetM <= 0
        ? 0.0
        : (segmentProgressM / segmentTargetM).clamp(0.0, 1.0);

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
      bottomNavigationBar: _buildControlsBar(readiness),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          _buildNoticeBanner(
            context,
            noticeText: noticeText,
            noticeColor: noticeColor,
          ),
          const SizedBox(height: 16),
          AppSurfaceCard(
            title: 'Mode Pengujian',
            subtitle: 'Pilih profil gerak agar GPS dan movement lebih cocok dengan skenario pengujian Anda.',
            accentColor: theme.colorScheme.secondary,
            trailing: StatusBadge(
              label: sensitivityProfile.label,
              color: theme.colorScheme.secondary,
              icon: Icons.tune_rounded,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TrackingSensitivityProfile.all.map((profile) {
                    return ChoiceChip(
                      label: Text(profile.label),
                      selected: _tripRecorderService.sensitivityMode == profile.mode,
                      onSelected: _tripRecorderService.isRecording
                          ? null
                          : (_) => _handleSensitivityChanged(profile.mode),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  sensitivityProfile.helperText,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_isRunning) ...[
            _buildGuidanceCard(context, readiness),
            const SizedBox(height: 16),
          ],
          if (_isRunning) ...[
            AppSurfaceCard(
              title: 'GPS Tracking',
              subtitle: 'Status posisi, kecepatan, dan progress segmen diperbarui secara realtime dengan refresh UI yang lebih ringan.',
              accentColor: theme.colorScheme.primary,
              trailing: StatusBadge(
                label: gpsQuality,
                color: gpsColor,
                icon: gpsQuality == 'Good' ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth < 520 ? 2 : 3;
                      final childAspectRatio = crossAxisCount == 2 ? 1.65 : 1.45;

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: childAspectRatio,
                        children: [
                          _buildMetricTile('Lat', locSample != null ? locSample.latitude.toStringAsFixed(5) : '--'),
                          _buildMetricTile('Lng', locSample != null ? locSample.longitude.toStringAsFixed(5) : '--'),
                          _buildMetricTile('Acc (m)', locSample != null ? locSample.accuracy.toStringAsFixed(1) : '--'),
                          _buildMetricTile('Speed', '${previewSpeedKmh.toStringAsFixed(2)} km/h'),
                          _buildMetricTile('Movement', isMoving ? 'Moving' : 'Stopped', valueColor: isMoving ? Colors.green : theme.colorScheme.onSurface),
                          _buildMetricTile('Distance', '${totalDistanceM.toStringAsFixed(1)} m'),
                          _buildMetricTile('Seg Start', activeSegment.distanceStartM.toStringAsFixed(1)),
                          _buildMetricTile('Seg End', activeSegment.distanceEndM.toStringAsFixed(1)),
                          _buildMetricTile('GPS Update', _formatGpsAge(gpsUpdateAge), valueColor: gpsUpdateAge == null || gpsUpdateAge <= const Duration(seconds: 3) ? Colors.green : Colors.orange),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Segment Progress: ${segmentProgressM.toStringAsFixed(0)} / ${segmentTargetM.toStringAsFixed(0)} m',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: segmentProgress,
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_tripRecorderService.isRecording) ...[
              Builder(
                builder: (context) {
                  final candidate = activeSegment;
                  final cond = candidate.roadCondition;
                  Color condColor = Colors.grey;
                  if (cond == 'good') condColor = Colors.green;
                  if (cond == 'uneven_road' || cond == 'slightly_uneven') condColor = Colors.orange;
                  if (cond == 'pothole_indication') condColor = Colors.deepOrange;
                  if (cond == 'severe_damage') condColor = Colors.red;

                  return AppSurfaceCard(
                    title: 'Segmen aktif ${candidate.distanceStartM.toStringAsFixed(0)} - ${candidate.distanceEndM.toStringAsFixed(0)} m',
                    subtitle: 'Ringkasan segmen sementara ini diambil dari data yang sedang direkam.',
                    accentColor: condColor,
                    trailing: StatusBadge(
                      label: cond.replaceAll('_', ' ').toUpperCase(),
                      color: condColor,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 420;
                        if (stacked) {
                          return Column(
                            children: [
                              _buildMetricTile('Avg Spd', '${candidate.avgSpeedKmh?.toStringAsFixed(1) ?? '0.0'} km/h'),
                              const SizedBox(height: 10),
                              _buildMetricTile('Max Vib', candidate.maxVibration?.toStringAsFixed(2) ?? '0.00'),
                              const SizedBox(height: 10),
                              _buildMetricTile('Events', candidate.eventCount.toString()),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: _buildMetricTile('Avg Spd', '${candidate.avgSpeedKmh?.toStringAsFixed(1) ?? '0.0'} km/h')),
                            const SizedBox(width: 10),
                            Expanded(child: _buildMetricTile('Max Vib', candidate.maxVibration?.toStringAsFixed(2) ?? '0.00')),
                            const SizedBox(width: 10),
                            Expanded(child: _buildMetricTile('Events', candidate.eventCount.toString())),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            AppSurfaceCard(
              title: 'Detection Status',
              subtitle: _tripRecorderService.isRecording
                  ? 'Status event dan kesiapan upload dipantau selama cloud recording aktif.'
                  : 'Deteksi pothole aktif setelah recording dimulai.',
              accentColor: _tripRecorderService.isRecording ? theme.colorScheme.tertiary : theme.colorScheme.outline,
              trailing: StatusBadge(
                label: _tripRecorderService.isRecording ? 'Active' : 'Inactive',
                color: _tripRecorderService.isRecording ? theme.colorScheme.tertiary : Colors.grey,
              ),
              child: _tripRecorderService.isRecording
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Events: ${_tripRecorderService.generatedEventsCount} total (${_tripRecorderService.bufferedEventsCount} buf / ${_tripRecorderService.uploadedEventsCount} up)',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        if (gpsQuality == 'Poor')
                          const Text('GPS accuracy is poor. Events will not be saved.', style: TextStyle(color: Colors.orange))
                        else if (_tripRecorderService.latestEvent != null) ...[
                          Text('Latest Event: ${_tripRecorderService.latestEvent!.eventType} (${_tripRecorderService.latestEvent!.severity})'),
                          Text('Vibration: ${_tripRecorderService.latestEvent!.vibration.toStringAsFixed(2)}'),
                          Text('Speed: ${_tripRecorderService.latestEvent!.speed.toStringAsFixed(1)} km/h'),
                        ] else
                          const Text('No events detected yet.', style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : const Text('Preview membantu cek sensor dulu. Recording dibutuhkan agar deteksi dan upload event berjalan penuh.'),
            ),
            const SizedBox(height: 16),
          ],
          if (!_tripRecorderService.isRecording)
            AppSurfaceCard(
              title: 'Recording Readiness',
              subtitle: 'Checklist ini membantu memastikan session siap direkam tanpa data kosong.',
              accentColor: theme.colorScheme.tertiary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          AppSurfaceCard(
            title: 'Accelerometer',
            subtitle: _isRunning
                ? 'Grafik dibatasi pada jendela kecil dan refresh bertahap agar preview lebih lancar.'
                : 'Mulai preview untuk melihat getaran dan status sensor secara langsung.',
            accentColor: theme.colorScheme.primary,
            trailing: StatusBadge(
              label: roadStatus.toUpperCase(),
              color: roadStatusColor,
            ),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 520 ? 2 : 3;
                    final childAspectRatio = crossAxisCount == 2 ? 1.7 : 1.45;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                      children: [
                        _buildMetricTile('X', vibSample != null ? vibSample.x.toStringAsFixed(2) : '--'),
                        _buildMetricTile('Y', vibSample != null ? vibSample.y.toStringAsFixed(2) : '--'),
                        _buildMetricTile('Z', vibSample != null ? vibSample.z.toStringAsFixed(2) : '--'),
                        _buildMetricTile('Magnitude', vibSample != null ? vibSample.magnitude.toStringAsFixed(2) : '--'),
                        _buildMetricTile('Vibration', vibSample != null ? vibSample.vibration.toStringAsFixed(2) : '--'),
                        _buildMetricTile('Status', roadStatus.toUpperCase(), valueColor: roadStatusColor),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: VibrationChart(samples: _samples),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(
    BuildContext context, {
    required String noticeText,
    required Color noticeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: noticeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: noticeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _tripRecorderService.isRecording ? Icons.fiber_manual_record : Icons.info_outline,
            color: noticeColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noticeText,
                  style: TextStyle(color: noticeColor, fontWeight: FontWeight.w700, height: 1.4),
                ),
                if (_tripRecorderService.isRecording && _tripRecorderService.activeSessionId != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Session ID: ${_tripRecorderService.activeSessionId!.substring(0, 8)}...',
                    style: TextStyle(color: noticeColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(BuildContext context, RecordingReadinessChecklist readiness) {
    final theme = Theme.of(context);
    return AppSurfaceCard(
      title: 'Sebelum mulai preview',
      subtitle: 'Layar dibuat lebih ringkas saat idle agar pengguna fokus pada langkah berikutnya dan aplikasi lebih ringan.',
      accentColor: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: readiness.hasGpsData ? 'GPS Ready' : 'GPS belum siap',
                color: readiness.hasGpsData ? Colors.green : Colors.red,
                icon: readiness.hasGpsData ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              ),
              StatusBadge(
                label: readiness.hasAccelerometerData ? 'Sensor Ready' : 'Sensor belum siap',
                color: readiness.hasAccelerometerData ? Colors.green : Colors.red,
                icon: readiness.hasAccelerometerData ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Tekan Start Preview untuk mulai membaca GPS dan accelerometer. Setelah data masuk dan akurasi GPS sudah cukup baik, tombol Start Recording akan aktif.'),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(RecordingReadinessChecklist readiness) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : (_isRunning ? _stopPreview : _startPreview),
                    icon: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_isRunning ? 'Stop Preview' : 'Start Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.grey.shade200 : Colors.green.shade100,
                      foregroundColor: _isRunning ? Colors.grey.shade900 : Colors.green.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tripRecorderService.isRecording
                      ? FilledButton.icon(
                          onPressed: _isLoading ? null : _stopRecording,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop Recording'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: (_isLoading || !readiness.isReady) ? null : _startRecording,
                          icon: const Icon(Icons.fiber_manual_record),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade900,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_tripRecorderService.isRecording) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingPhoto ? null : _takePhoto,
                      icon: _isUploadingPhoto
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt_rounded),
                      label: Text(_isUploadingPhoto ? 'Uploading...' : 'Take Photo ($_sessionPhotoCount)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRunning ? _resetBaseline : null,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  String _formatGpsAge(Duration? age) {
    if (age == null) return '--';
    if (age.inSeconds < 1) return '<1 sec';
    return '${age.inSeconds} sec';
  }
}
