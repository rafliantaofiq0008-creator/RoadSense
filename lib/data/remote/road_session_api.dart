import 'package:flutter/foundation.dart';

import '../models/road_session.dart';
import 'supabase_service.dart';

class RoadSessionApi {
  static const String tableName = 'road_sessions';

  Future<void> createSession(RoadSession session) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    if (session.userId != userId) {
      throw Exception('Cannot create session for a different user.');
    }

    final data = session.toMap();
    await client.from(tableName).insert(data);
  }

  Future<void> updateSessionSummary(RoadSession session) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    if (session.userId != userId) {
      throw Exception('Cannot update session for a different user.');
    }

    final data = session.toMap();
    await client.from(tableName).update(data).eq('id', session.id);
  }

  Future<List<RoadSession>> getSessionsForCurrentUser() async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    final response = await client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .order('start_time', ascending: false);

    return (response as List).map((data) => RoadSession.fromMap(data)).toList();
  }

  Future<RoadSession?> getSessionById(String id) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser.id;

    final response = await client
        .from(tableName)
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return RoadSession.fromMap(response);
  }

  Future<void> deleteSession(String id) async {
    final client = SupabaseService.client;
    // RLS should ensure the user can only delete their own sessions, 
    // but we can also filter by user_id explicitly just in case.
    final userId = SupabaseService.currentUser.id;

    // 1. Delete associated photo files from Supabase Storage first
    try {
      final photosResponse = await client
          .from('road_photos')
          .select('storage_bucket, storage_path')
          .eq('session_id', id);

      final photos = photosResponse as List<dynamic>;
      for (var photo in photos) {
        final bucket = photo['storage_bucket'] as String?;
        final path = photo['storage_path'] as String?;
        if (bucket != null && path != null) {
          await client.storage.from(bucket).remove([path]);
        }
      }
    } catch (e) {
      // Ignore errors during file cleanup so the session can still be deleted
      debugPrint('Warning: Failed to cleanup storage files for session: $e');
    }

    // 2. Delete the session from DB (Cascade will delete readings, events, photos DB rows)
    await client
        .from(tableName)
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }
}
