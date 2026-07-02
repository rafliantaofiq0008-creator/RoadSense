import '../models/road_reading.dart';
import 'supabase_service.dart';

class RoadReadingApi {
  static const String tableName = 'road_readings';

  Future<void> upsertReadingsBatch(List<RoadReading> readings) async {
    if (readings.isEmpty) return;

    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    final dataList = readings.map((reading) {
      if (reading.userId != userId) {
        throw Exception('Cannot insert readings for a different user.');
      }
      final data = reading.toMap();
      return data;
    }).toList();

    await client.from(tableName).upsert(dataList);
  }

  Future<List<RoadReading>> getReadingsBySessionId(String sessionId) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    final response = await client
        .from(tableName)
        .select()
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .order('recorded_at', ascending: true);

    return (response as List).map((data) => RoadReading.fromMap(data)).toList();
  }
}
