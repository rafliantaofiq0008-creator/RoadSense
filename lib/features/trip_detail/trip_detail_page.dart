import 'package:flutter/material.dart';
import '../../data/remote/road_reading_api.dart';
import '../../data/remote/road_session_api.dart';
import '../../data/models/road_reading.dart';
import '../../data/models/road_session.dart';
import '../../data/models/road_event.dart';
import '../../data/remote/road_event_api.dart';
import '../../data/models/vibration_sample.dart';
import '../../shared/charts/vibration_chart.dart';
import '../../core/utils/map_utils.dart';
import '../../data/remote/ai_report_api.dart';
import '../ai_report/ai_report_list_page.dart';
import '../ai_report/ai_report_page.dart';
import '../map/map_page.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../data/remote/road_photo_api.dart';
import '../../data/models/road_photo.dart';
import '../../data/remote/road_segment_analysis_api.dart';
import '../../data/models/road_segment_analysis.dart';
import '../../core/utils/app_date_time.dart';
import '../../shared/widgets/app_surface_card.dart';
import '../../shared/widgets/status_badge.dart';

class TripDetailPage extends StatefulWidget {
  final String sessionId;

  const TripDetailPage({super.key, required this.sessionId});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  final RoadSessionApi _sessionApi = RoadSessionApi();
  final RoadReadingApi _readingApi = RoadReadingApi();
  final RoadEventApi _eventApi = RoadEventApi();
  final RoadPhotoApi _photoApi = RoadPhotoApi();
  final RoadSegmentAnalysisApi _segmentApi = RoadSegmentAnalysisApi();
  final ImagePicker _picker = ImagePicker();

  RoadSession? _session;
  List<RoadReading> _readings = [];
  List<RoadEvent> _events = [];
  List<RoadPhoto> _photos = [];
  List<RoadSegmentAnalysis> _segments = [];
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadTripData();
  }

  Future<void> _loadTripData() async {
    setState(() => _isLoading = true);
    try {
      final session = await _sessionApi.getSessionById(widget.sessionId);
      final readings = await _readingApi.getReadingsBySessionId(
        widget.sessionId,
      );
      final events = await _eventApi.getEventsBySessionId(widget.sessionId);
      final photos = await _photoApi.getPhotosForSession(widget.sessionId);
      final segments = await _segmentApi.getSegmentsForSession(
        widget.sessionId,
      );

      if (mounted) {
        setState(() {
          _session = session;
          _readings = readings;
          _events = events;
          _photos = photos;
          _segments = segments;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trip details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateReport(BuildContext context) async {
    if (_readings.length < 10) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Data Terbatas'),
          content: const Text(
            'Data perjalanan masih terbatas. Laporan tetap dapat dibuat, tetapi tingkat keakuratannya perlu diverifikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Generating AI Report..."),
          ],
        ),
      ),
    );

    try {
      final report = await AiReportApi().generateReportForSession(
        widget.sessionId,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AiReportPage(report: report)),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
    }
  }

  ({String label, String recommendation, Color color}) _mapCondition(
    String condition,
  ) {
    String label = '';
    String recommendation;
    Color color;

    switch (condition) {
      case 'not_assessed':
        label = 'Tidak Dapat Dinilai';
        recommendation = 'Survei ulang';
        color = Colors.grey;
        break;
      case 'good':
        label = 'Relatif Baik';
        recommendation = 'Monitoring';
        color = Colors.green;
        break;
      case 'slightly_uneven':
        label = 'Sedikit Tidak Rata';
        recommendation = 'Monitoring';
        color = Colors.lime;
        break;
      case 'uneven_road':
        label = 'Jalan Bergelombang / Tidak Rata';
        recommendation = 'Inspeksi & Perataan';
        color = Colors.orange;
        break;
      case 'pothole_indication':
        label = 'Indikasi Lubang Jalan';
        recommendation = 'Verifikasi & Patching';
        color = Colors.deepOrange;
        break;
      case 'severe_damage':
        label = 'Kerusakan Berat';
        recommendation = 'Prioritas Perbaikan';
        color = Colors.red;
        break;
      case 'speed_bump_candidate':
        label = 'Indikasi Polisi Tidur / Elevasi';
        recommendation = 'Validasi Lapangan';
        color = Colors.purple;
        break;
      default:
        label = condition;
        recommendation = '-';
        color = Colors.grey;
    }

    return (label: label, recommendation: recommendation, color: color);
  }

  Future<void> _addRetroactivePhoto() async {
    if (_session == null) return;
    try {
      final XFile? xfile = await _picker.pickImage(source: ImageSource.camera);
      if (xfile == null) return;

      setState(() => _isUploadingPhoto = true);

      final File file = File(xfile.path);
      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        final resizedImage = img.copyResize(decodedImage, width: 800);
        await file.writeAsBytes(img.encodeJpg(resizedImage, quality: 70));
      }

      await _photoApi.uploadPhotoForSession(
        sessionId: _session!.id,
        imageFile: file,
        caption: 'Retroactive road photo',
      );

      final photos = await _photoApi.getPhotosForSession(_session!.id);

      if (mounted) {
        setState(() => _photos = photos);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _deletePhoto(RoadPhoto photo) async {
    try {
      await _photoApi.deletePhoto(photo);
      final photos = await _photoApi.getPhotosForSession(_session!.id);
      if (mounted) {
        setState(() => _photos = photos);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editCaption(RoadPhoto photo) async {
    final tc = TextEditingController(text: photo.caption ?? '');
    final newCaption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Caption'),
        content: TextField(
          controller: tc,
          decoration: const InputDecoration(labelText: 'Caption'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, tc.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newCaption == null) return;
    try {
      await _photoApi.updatePhotoCaption(photo.id, newCaption);
      final photos = await _photoApi.getPhotosForSession(_session!.id);
      if (mounted) setState(() => _photos = photos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update caption: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatEventLabel(String value) {
    switch (value) {
      case 'smooth_road':
        return 'Jalan Halus';
      case 'damaged_road':
        return 'Jalan Rusak';
      case 'pothole':
        return 'Lubang Jalan';
      case 'severe_pothole':
        return 'Lubang Parah';
      default:
        return value
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  String _formatSeverityLabel(String value) {
    switch (value) {
      case 'normal':
        return 'Normal';
      case 'damaged':
        return 'Rusak';
      case 'pothole':
        return 'Lubang';
      case 'severe_pothole':
        return 'Parah';
      default:
        return _formatEventLabel(value);
    }
  }

  Color _eventSeverityColor(BuildContext context, String severity) {
    final scheme = Theme.of(context).colorScheme;
    switch (severity) {
      case 'severe_pothole':
        return scheme.error;
      case 'pothole':
        return Colors.deepOrange;
      case 'damaged':
        return scheme.secondary;
      case 'normal':
        return scheme.tertiary;
      default:
        return scheme.primary;
    }
  }

  Widget _buildEventMetricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedEventCard(RoadEvent event) {
    final theme = Theme.of(context);
    final severityColor = _eventSeverityColor(context, event.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sensors_rounded,
                  size: 19,
                  color: severityColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatEventLabel(event.eventType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppDateTime.formatSession(event.recordedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatSeverityLabel(event.severity),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: severityColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEventMetricChip(
                icon: Icons.multiline_chart_rounded,
                label: 'Vib',
                value: event.vibration.toStringAsFixed(2),
              ),
              _buildEventMetricChip(
                icon: Icons.speed_rounded,
                label: 'Speed',
                value: '${event.speed.toStringAsFixed(1)} km/h',
              ),
              _buildEventMetricChip(
                icon: Icons.my_location_rounded,
                label: 'GPS',
                value: '${event.gpsAccuracy.toStringAsFixed(1)} m',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Lat ${event.latitude.toStringAsFixed(5)}, Lng ${event.longitude.toStringAsFixed(5)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedEventsSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Detected Events',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            StatusBadge(
              label: '${_events.length} event',
              color: theme.colorScheme.secondary,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._events.map(_buildDetectedEventCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Details')),
        body: const Center(child: Text('Trip not found.')),
      );
    }

    final s = _session!;
    final displayTitle = AppDateTime.displaySessionTitle(s);

    // Convert readings to VibrationSamples for the chart
    final chartSamples = _readings
        .map(
          (r) => VibrationSample(
            timestamp: r.recordedAt,
            x: r.accelerationX,
            y: r.accelerationY,
            z: r.accelerationZ,
            magnitude: r.magnitude,
            vibration: r.vibration,
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(displayTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSurfaceCard(
                title: 'Ringkasan trip',
                subtitle:
                    'Waktu lokal digunakan agar jam pengujian sesuai dengan kondisi nyata di perangkat.',
                accentColor: Theme.of(context).colorScheme.primary,
                trailing: const StatusBadge(
                  label: 'Saved to Cloud',
                  color: Colors.green,
                  icon: Icons.cloud_done_rounded,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start: ${AppDateTime.formatSession(s.startTime)}'),
                    if (s.endTime != null)
                      Text('End: ${AppDateTime.formatSession(s.endTime)}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusBadge(
                          label:
                              'Avg ${s.averageSpeed?.toStringAsFixed(1) ?? '0.0'} km/h',
                          color: Theme.of(context).colorScheme.primary,
                          icon: Icons.speed_rounded,
                        ),
                        StatusBadge(
                          label:
                              'Max ${s.maxSpeed?.toStringAsFixed(1) ?? '0.0'} km/h',
                          color: Theme.of(context).colorScheme.tertiary,
                          icon: Icons.north_east_rounded,
                        ),
                        StatusBadge(
                          label:
                              'Vib ${s.maxVibration?.toStringAsFixed(2) ?? '0.0'}',
                          color: Theme.of(context).colorScheme.secondary,
                          icon: Icons.multiline_chart_rounded,
                        ),
                        StatusBadge(
                          label: '${_events.length} event',
                          color: Colors.deepOrange,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Total Readings: ${_readings.length}'),
                        ),
                        Expanded(
                          child: Text(
                            'Distance: ${s.estimatedDistanceKm?.toStringAsFixed(2) ?? '0.00'} km',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final validPoints = MapUtils.filterValidRoutePoints(
                            _readings,
                          );
                          if (validPoints.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Warning: Not enough GPS points to draw a route for this trip.',
                                ),
                              ),
                            );
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapPage(initialSessionId: s.id),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('View on Map'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AiReportListPage(sessionId: s.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.list_alt),
                            label: const Text('AI Reports'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _generateReport(context),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Generate'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (chartSamples.isNotEmpty) ...[
                Text(
                  'Vibration History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: VibrationChart(samples: chartSamples),
                  ),
                ),
              ] else
                const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text('No readings recorded for this trip.'),
                  ),
                ),

              const SizedBox(height: 24),
              if (_segments.isNotEmpty) ...[
                const Text(
                  'Analisis Jalan Berdasarkan Jarak',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade200,
                        ),
                        columns: const [
                          DataColumn(label: Text('Segmen')),
                          DataColumn(label: Text('Jarak (m)')),
                          DataColumn(label: Text('Panjang')),
                          DataColumn(label: Text('Avg Spd')),
                          DataColumn(label: Text('Max Spd')),
                          DataColumn(label: Text('Avg Vib')),
                          DataColumn(label: Text('Max Vib')),
                          DataColumn(label: Text('Peak Vert')),
                          DataColumn(label: Text('GPS Avg')),
                          DataColumn(label: Text('Readings')),
                          DataColumn(label: Text('Event')),
                          DataColumn(label: Text('Confidence')),
                          DataColumn(label: Text('Kondisi')),
                          DataColumn(label: Text('Skor')),
                          DataColumn(label: Text('Solusi')),
                        ],
                        rows: _segments.map((seg) {
                          final mapped = _mapCondition(seg.roadCondition);
                          return DataRow(
                            cells: [
                              DataCell(Text(seg.segmentIndex.toString())),
                              DataCell(
                                Text(
                                  '${seg.distanceStartM.toStringAsFixed(0)} - ${seg.distanceEndM.toStringAsFixed(0)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${seg.segmentLengthM.toStringAsFixed(0)} m',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${seg.avgSpeedKmh?.toStringAsFixed(1) ?? "-"} km/h',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${seg.maxSpeedKmh?.toStringAsFixed(1) ?? "-"} km/h',
                                ),
                              ),
                              DataCell(
                                Text(
                                  seg.avgVibration?.toStringAsFixed(2) ?? "-",
                                ),
                              ),
                              DataCell(
                                Text(
                                  seg.maxVibration?.toStringAsFixed(2) ?? "-",
                                ),
                              ),
                              DataCell(
                                Text(
                                  seg.verticalPeak?.toStringAsFixed(2) ?? "-",
                                ),
                              ),
                              DataCell(
                                Text(
                                  seg.gpsAccuracyAvg?.toStringAsFixed(1) ?? "-",
                                ),
                              ),
                              DataCell(Text(seg.readingsCount.toString())),
                              DataCell(Text(seg.eventCount.toString())),
                              DataCell(
                                Text(seg.dataConfidenceLevel.toUpperCase()),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mapped.color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    mapped.label,
                                    style: TextStyle(
                                      color: mapped.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  seg.conditionScore?.toStringAsFixed(0) ?? "-",
                                ),
                              ),
                              DataCell(Text(mapped.recommendation)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Photo Gallery
              if (_photos.isNotEmpty || _isUploadingPhoto) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Road Evidence Photos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_isUploadingPhoto)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: _addRetroactivePhoto,
                        icon: const Icon(Icons.add_a_photo, size: 16),
                        label: const Text('Add Photo'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      return Card(
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Expanded(
                                child: photo.signedUrl != null
                                    ? Image.network(
                                        photo.signedUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                    : const Icon(
                                        Icons.image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                photo.caption ?? 'No caption',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  InkWell(
                                    onTap: () => _editCaption(photo),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Photo?'),
                                          content: const Text(
                                            'Cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _deletePhoto(photo);
                                              },
                                              child: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.delete,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Road Evidence Photos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_isUploadingPhoto)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: _addRetroactivePhoto,
                        icon: const Icon(Icons.add_a_photo, size: 16),
                        label: const Text('Add Photo'),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No photos attached to this session.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
              if (_events.isNotEmpty)
                _buildDetectedEventsSection(), // end of _events.isNotEmpty
            ], // end of Column children
          ), // end of Column
        ), // end of SingleChildScrollView
      ), // end of Padding
    ); // end of Scaffold
  } // end of build method
} // end of class
