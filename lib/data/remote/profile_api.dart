import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import 'supabase_service.dart';

class ProfileApi {
  static const String tableName = 'profiles';
  final AuthService _authService = AuthService();

  Future<void> upsertCurrentUserProfile(String fullName, String email) async {
    final userId = _authService.getCurrentUserId();
    final client = SupabaseService.client;

    try {
      await client.from(tableName).upsert({
        'id': userId,
        'full_name': fullName,
        'email': email,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to update profile: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while updating profile.');
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = _authService.getCurrentUserId();
    final client = SupabaseService.client;

    try {
      final response = await client
          .from(tableName)
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch profile: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while fetching profile.');
    }
  }
}
