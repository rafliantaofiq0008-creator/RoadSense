import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/road_photo.dart';

class RoadPhotoApi {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<RoadPhoto> uploadPhotoForSession({
    required String sessionId,
    required File imageFile,
    String? caption,
    String photoType = 'manual',
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    double? speed,
    double? vibration,
    String? eventId,
    int? segmentIndex,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not authenticated.");

    final photoId = _uuid.v4();
    final storagePath = 'users/$userId/sessions/$sessionId/photos/$photoId.jpg';

    // Upload to Supabase Storage
    try {
      await _supabase.storage.from('road-photos').upload(storagePath, imageFile);
    } on StorageException catch (e) {
      if (e.message.contains('Bucket not found') || e.statusCode == '404' || e.error == 'Bucket not found') {
        throw Exception("Road photo storage belum tersedia. Pastikan bucket road-photos sudah dibuat.");
      }
      rethrow;
    }

    // Prepare metadata
    final photoData = {
      'id': photoId,
      'user_id': userId,
      'session_id': sessionId,
      'event_id': eventId,
      'segment_index': segmentIndex,
      'storage_bucket': 'road-photos',
      'storage_path': storagePath,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'speed': speed,
      'vibration': vibration,
      'caption': caption,
      'photo_type': photoType,
      'taken_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Insert into database
    final result = await _supabase
        .from('road_photos')
        .insert(photoData)
        .select()
        .single();

    final photo = RoadPhoto.fromMap(result);
    photo.signedUrl = await createSignedUrl(photo);
    return photo;
  }

  Future<List<RoadPhoto>> getPhotosForSession(String sessionId) async {
    final response = await _supabase
        .from('road_photos')
        .select()
        .eq('session_id', sessionId)
        .order('taken_at', ascending: true);

    final photos = response.map((e) => RoadPhoto.fromMap(e)).toList();
    
    // Generate signed URLs for each
    for (var photo in photos) {
      photo.signedUrl = await createSignedUrl(photo);
    }
    
    return photos;
  }

  Future<RoadPhoto> updatePhotoCaption(String photoId, String caption) async {
    final response = await _supabase
        .from('road_photos')
        .update({'caption': caption})
        .eq('id', photoId)
        .select()
        .single();
    return RoadPhoto.fromMap(response);
  }

  Future<void> deletePhoto(RoadPhoto photo) async {
    // 1. Delete from storage
    try {
      await _supabase.storage.from(photo.storageBucket).remove([photo.storagePath]);
    } catch (e) {
      // Failed to delete photo from storage, intentionally ignored here
    }

    // 2. Delete from database
    await _supabase
        .from('road_photos')
        .delete()
        .eq('id', photo.id);
  }

  Future<String> createSignedUrl(RoadPhoto photo) async {
    // 1 year expiry for ease, since they are session-specific and private
    return await _supabase.storage
        .from(photo.storageBucket)
        .createSignedUrl(photo.storagePath, 60 * 60 * 24 * 365);
  }
}
