import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class SupabaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    SupabaseConfig.validate();

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw Exception('SupabaseService has not been initialized. Call initialize() first.');
    }
    return Supabase.instance.client;
  }

  static User get currentUser {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }
    return user;
  }
}
