import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/data/remote/supabase_config.dart';
import 'package:roadsense/services/auth_service.dart';

void main() {
  group('Auth Service & Config Tests', () {
    test('SupabaseConfig validate throws if environment variables are missing', () {
      // In tests, String.fromEnvironment for SUPABASE_URL and SUPABASE_ANON_KEY will be empty
      // unless provided via command line args.
      
      expect(
        () => SupabaseConfig.validate(),
        throwsA(isA<Exception>()),
      );
    });

    test('AuthService can be constructed', () {
      final authService = AuthService();
      expect(authService, isNotNull);
    });

    test('AuthService throws when accessing client before initialization', () {
      final authService = AuthService();
      expect(
        () => authService.getCurrentUserId(), 
        throwsA(isA<Exception>()),
      );
    });
  });
}
