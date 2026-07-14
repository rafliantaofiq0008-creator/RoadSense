import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/map_utils.dart';
import '../../core/utils/app_date_time.dart';
import '../../data/models/road_session.dart';
import '../../data/models/road_event.dart';
import '../../data/remote/road_session_api.dart';
import '../../data/remote/road_reading_api.dart';
import '../../data/remote/road_event_api.dart';
import '../../shared/widgets/app_surface_card.dart';
import '../../shared/widgets/status_badge.dart';

class MapPage extends StatefulWidget {
  final String? initialSessionId;

  const MapPage({super.key, this.initialSessionId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _sessionApi = RoadSessionApi();
  final _readingApi = RoadReadingApi();
  final _eventApi = RoadEventApi();

  List<RoadSession> _sessions = [];
  RoadSession? _selectedSession;
  
  List<LatLng> _routePoints = [];
  List<RoadEvent> _events = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _sessions = await _sessionApi.getSessionsForCurrentUser();
      
      if (_sessions.isNotEmpty) {
        if (widget.initialSessionId != null) {
          _selectedSession = _sessions.firstWhere(
            (s) => s.id == widget.initialSessionId, 
            orElse: () => _sessions.first
          );
        } else {
          _selectedSession = _sessions.first;
        }
        await _loadMapData(_selectedSession!);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMapData(RoadSession session) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _routePoints = [];
      _events = [];
    });

    try {
      final readings = await _readingApi.getReadingsBySessionId(session.id);
      final rawPoints = MapUtils.filterValidRoutePoints(readings);
      _routePoints = MapUtils.downsampleRoutePoints(rawPoints, maxPoints: 1000);
      
      final rawEvents = await _eventApi.getEventsBySessionId(session.id);
      _events = rawEvents.where((e) => MapUtils.isValidCoordinate(e.latitude, e.longitude)).toList();
      
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSessionSelected(RoadSession? session) {
    if (session != null && session.id != _selectedSession?.id) {
      setState(() => _selectedSession = session);
      _loadMapData(session);
    }
  }

  void _showEventDetails(RoadEvent event) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Event: ${event.eventType.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Severity: ${event.severity}'),
              Text('Vibration: ${event.vibration.toStringAsFixed(2)}'),
              Text('Speed: ${event.speed.toStringAsFixed(1)} km/h'),
              Text('GPS Accuracy: ${event.gpsAccuracy.toStringAsFixed(1)} m'),
              Text('Coordinates: ${event.latitude.toStringAsFixed(5)}, ${event.longitude.toStringAsFixed(5)}'),
              Text('Time: ${AppDateTime.formatDetailed(event.recordedAt)}'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Visualization'),
      ),
      body: Column(
        children: [
          // Session Selector
          if (_sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AppSurfaceCard(
                title: 'Pilih sesi trip',
                subtitle: 'Gunakan peta untuk membandingkan rute dan titik event pada sesi yang berbeda.',
                accentColor: Theme.of(context).colorScheme.primary,
                trailing: const StatusBadge(
                  label: 'OSM',
                  color: Color(0xFF2D5364),
                  icon: Icons.layers_rounded,
                ),
                child: DropdownButtonFormField<RoadSession>(
                  decoration: const InputDecoration(
                    labelText: 'Trip session',
                  ),
                  initialValue: _selectedSession,
                  isExpanded: true,
                  items: _sessions.map((session) {
                    final start = AppDateTime.formatSession(session.startTime);
                    return DropdownMenuItem(
                      value: session,
                      child: Text('${AppDateTime.displaySessionTitle(session)} • $start'),
                    );
                  }).toList(),
                  onChanged: _onSessionSelected,
                ),
              ),
            ),
            
          // Map Area
          Expanded(
            child: _buildMapArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)));
    }

    if (_sessions.isEmpty) {
      return const Center(child: Text('No trips recorded yet.'));
    }

    if (_routePoints.length < 2 && _events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: AppSurfaceCard(
            title: 'Rute belum cukup',
            subtitle: 'Trip ini belum memiliki cukup titik GPS untuk digambar sebagai lintasan.',
            accentColor: Theme.of(context).colorScheme.secondary,
            trailing: Icon(Icons.gps_off_rounded, color: Theme.of(context).colorScheme.secondary),
            child: const Text('Coba pilih sesi lain atau rekam ulang dengan GPS yang lebih stabil.'),
          ),
        ),
      );
    }

    final eventPoints = _events.map((e) => LatLng(e.latitude, e.longitude)).toList();
    final initialCenter = MapUtils.calculateMapCenter(
      routePoints: _routePoints, 
      eventPoints: eventPoints
    );

    return FlutterMap(
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.roadsense.app',
        ),
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
        MarkerLayer(
          markers: _events.map((event) {
            Color markerColor = Colors.orange;
            if (event.severity == 'medium') markerColor = Colors.deepOrange;
            if (event.severity == 'high') markerColor = Colors.red;

            return Marker(
              point: LatLng(event.latitude, event.longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showEventDetails(event),
                child: Icon(Icons.location_on, color: markerColor, size: 40),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
