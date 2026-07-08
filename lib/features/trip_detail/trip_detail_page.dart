import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      final readings = await _readingApi.getReadingsBySessionId(widget.sessionId);
      final events = await _eventApi.getEventsBySessionId(widget.sessionId);
      final photos = await _photoApi.getPhotosForSession(widget.sessionId);
      final segments = await _segmentApi.getSegmentsForSession(widget.sessionId);
      
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
          content: const Text('Data perjalanan masih terbatas. Laporan tetap dapat dibuat, tetapi tingkat keakuratannya perlu diverifikasi.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
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
      final report = await AiReportApi().generateReportForSession(widget.sessionId);
      
      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AiReportPage(report: report)),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    }
  }

  ({String label, String recommendation, Color color}) _mapCondition(String condition) {
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo added successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add photo: $e'), backgroundColor: Colors.red));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo deleted.')));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete photo: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editCaption(RoadPhoto photo) async {
    final tc = TextEditingController(text: photo.caption ?? '');
    final newCaption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Caption'),
        content: TextField(controller: tc, decoration: const InputDecoration(labelText: 'Caption')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, tc.text), child: const Text('Save')),
        ],
      ),
    );
    if (newCaption == null) return;
    try {
      await _photoApi.updatePhotoCaption(photo.id, newCaption);
      final photos = await _photoApi.getPhotosForSession(_session!.id);
      if (mounted) setState(() => _photos = photos);
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update caption: $e'), backgroundColor: Colors.red));
    }
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
    final format = DateFormat('MMM d, yyyy - HH:mm');

    // Convert readings to VibrationSamples for the chart
    final chartSamples = _readings.map((r) => VibrationSample(
      timestamp: r.recordedAt,
      x: r.accelerationX,
      y: r.accelerationY,
      z: r.accelerationZ,
      magnitude: r.magnitude,
      vibration: r.vibration,
    )).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Summary', style: Theme.of(context).textTheme.titleLarge),
                    const Divider(),
                    Text('Start: ${format.format(s.startTime.toLocal())}'),
                    if (s.endTime != null)
                      Text('End: ${format.format(s.endTime!.toLocal())}'),
                    const SizedBox(height: 8),
                    Text('Average Speed: ${s.averageSpeed?.toStringAsFixed(1) ?? '0.0'} km/h'),
                    Text('Max Speed: ${s.maxSpeed?.toStringAsFixed(1) ?? '0.0'} km/h'),
                    Text('Max Vibration: ${s.maxVibration?.toStringAsFixed(2) ?? '0.0'}'),
                    Text('Total Readings: ${_readings.length}'),
                    Text('Total Events: ${_events.length}'),
                    const Text('Status: Saved to Cloud', style: TextStyle(color: Colors.green)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final validPoints = MapUtils.filterValidRoutePoints(_readings);
                          if (validPoints.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Warning: Not enough GPS points to draw a route for this trip.')),
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
                                  builder: (_) => AiReportListPage(sessionId: s.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.list_alt),
                            label: const Text('AI Reports'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _generateReport(context),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Generate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade50,
                              foregroundColor: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (chartSamples.isNotEmpty) ...[
              Text('Vibration History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
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
              const Expanded(
                child: Center(child: Text('No readings recorded for this trip.')),
              ),
            
            const SizedBox(height: 24),
            if (_segments.isNotEmpty) ...[
              const Text('Analisis Jalan Berdasarkan Jarak', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                      columns: const [
                        DataColumn(label: Text('Segmen')),
                        DataColumn(label: Text('Jarak (m)')),
                        DataColumn(label: Text('Kecepatan')),
                        DataColumn(label: Text('Guncangan (Peak)')),
                        DataColumn(label: Text('Event')),
                        DataColumn(label: Text('Kondisi')),
                        DataColumn(label: Text('Solusi')),
                      ],
                      rows: _segments.map((seg) {
                        final mapped = _mapCondition(seg.roadCondition);
                        return DataRow(cells: [
                          DataCell(Text(seg.segmentIndex.toString())),
                          DataCell(Text('${seg.distanceStartM.toStringAsFixed(0)} - ${seg.distanceEndM.toStringAsFixed(0)}')),
                          DataCell(Text('${seg.avgSpeedKmh?.toStringAsFixed(1) ?? "-"} km/h')),
                          DataCell(Text(seg.verticalPeak?.toStringAsFixed(2) ?? "-")),
                          DataCell(Text(seg.eventCount.toString())),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: mapped.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(mapped.label, style: TextStyle(color: mapped.color, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          DataCell(Text(mapped.recommendation)),
                        ]);
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
                  Text('Road Evidence Photos', style: Theme.of(context).textTheme.titleMedium),
                  if (_isUploadingPhoto)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                                  ? Image.network(photo.signedUrl!, fit: BoxFit.cover, width: double.infinity)
                                  : const Icon(Icons.image, size: 40, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(photo.caption ?? 'No caption', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                InkWell(
                                  onTap: () => _editCaption(photo),
                                  child: const Icon(Icons.edit, size: 14, color: Colors.blue),
                                ),
                                InkWell(
                                  onTap: () {
                                     showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Photo?'),
                                          content: const Text('Cannot be undone.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                            TextButton(
                                              onPressed: () { Navigator.pop(ctx); _deletePhoto(photo); },
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                     );
                                  },
                                  child: const Icon(Icons.delete, size: 14, color: Colors.red),
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
                  Text('Road Evidence Photos', style: Theme.of(context).textTheme.titleMedium),
                  if (_isUploadingPhoto)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                child: Text('No photos attached to this session.', style: TextStyle(color: Colors.grey)),
              ),
            ],
            if (_events.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Detected Events', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${event.eventType} (${event.severity})'),
                        subtitle: Text(
                          'Vib: ${event.vibration.toStringAsFixed(2)} | Speed: ${event.speed.toStringAsFixed(1)} km/h\n'
                          'Lat: ${event.latitude.toStringAsFixed(5)}, Lng: ${event.longitude.toStringAsFixed(5)}\n'
                          'Time: ${format.format(event.recordedAt.toLocal())}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
