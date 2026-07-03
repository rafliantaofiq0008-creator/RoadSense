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
import '../map/map_page.dart';

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
  
  RoadSession? _session;
  List<RoadReading> _readings = [];
  List<RoadEvent> _events = [];
  bool _isLoading = true;

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
      
      if (mounted) {
        setState(() {
          _session = session;
          _readings = readings;
          _events = events;
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
