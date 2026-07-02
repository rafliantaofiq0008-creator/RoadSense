import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/remote/road_session_api.dart';
import '../../data/models/road_session.dart';
import '../trip_detail/trip_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final RoadSessionApi _sessionApi = RoadSessionApi();
  List<RoadSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _sessionApi.getSessionsForCurrentUser();
      if (mounted) {
        setState(() {
          _sessions = sessions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Trip History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No trips recorded yet.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final format = DateFormat('MMM d, yyyy - HH:mm');
    
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        itemCount: _sessions.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final session = _sessions[index];
          
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: ListTile(
              title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Started: ${format.format(session.startTime.toLocal())}'),
                  if (session.endTime != null)
                    Text('Ended: ${format.format(session.endTime!.toLocal())}'),
                  const SizedBox(height: 4),
                  Text('Avg Speed: ${session.averageSpeed?.toStringAsFixed(1) ?? '0.0'} km/h | Max Vib: ${session.maxVibration?.toStringAsFixed(2) ?? '0.0'}'),
                  Text(
                    'Events: ${session.totalEvents} | Status: Saved to Cloud', 
                    style: TextStyle(
                      color: Colors.green[700], 
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
              trailing: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done, color: Colors.green),
                  SizedBox(height: 4),
                  Text(
                    'Synced',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripDetailPage(sessionId: session.id),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
