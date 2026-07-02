import '../models/road_event.dart';
import 'supabase_service.dart';

class RoadEventApi {
  static const String tableName = 'road_events';

  Future<void> upsertEventsBatch(List<RoadEvent> events) async {
    if (events.isEmpty) return;

    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    final dataList = events.map((event) {
      if (event.userId != userId) {
        throw Exception('Cannot insert events for a different user.');
      }
      final data = event.toMap();
      return data;
    }).toList();

    await client.from(tableName).upsert(dataList);
  }

  Future<void> insertEvent(RoadEvent event) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    if (event.userId != userId) {
      throw Exception('Cannot insert event for a different user.');
    }

    final data = event.toMap();
    await client.from(tableName).insert(data);
  }

  Future<List<RoadEvent>> getEventsBySessionId(String sessionId) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    final response = await client
        .from(tableName)
        .select()
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .order('recorded_at', ascending: true);

    return (response as List).map((data) => RoadEvent.fromMap(data)).toList();
  }
}
