import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/road_segment_analysis.dart';

class RoadSegmentAnalysisApi {
  final SupabaseClient _supabase;

  RoadSegmentAnalysisApi({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;

  /// Inserts a batch of segment analyses for a session.
  Future<void> insertSegments(List<RoadSegmentAnalysis> segments) async {
    if (segments.isEmpty) return;

    final List<Map<String, dynamic>> data = segments.map((s) => s.toMap()).toList();
    
    // Batch insert using insert
    await _supabase.from('road_segment_analyses').insert(data);
  }

  /// Fetches segment analyses for a given session.
  Future<List<RoadSegmentAnalysis>> getSegmentsForSession(String sessionId) async {
    final response = await _supabase
        .from('road_segment_analyses')
        .select()
        .eq('session_id', sessionId)
        .order('segment_index', ascending: true);

    return (response as List).map((data) => RoadSegmentAnalysis.fromMap(data)).toList();
  }
}
