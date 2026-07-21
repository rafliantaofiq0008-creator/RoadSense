import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../data/remote/supabase_service.dart';

class AuthService {
  GoTrueClient get _auth => SupabaseService.client.auth;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Session? get currentSession {
    try {
      return _auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  bool get isAuthenticated => _auth.currentUser != null;

  String getCurrentUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }
    return user.id;
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      return response;
    } on AuthException catch (e) {
      throw Exception('Registration failed: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during registration.');
    }
  }

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during login.');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final redirectTo = _mobileRedirectTo;
      final launched = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      if (!launched) {
        throw Exception('Google Sign-In tidak bisa dibuka di perangkat ini.');
      }
    } on AuthException catch (e) {
      throw Exception('Google Sign-In gagal: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi masalah saat membuka Google Sign-In.');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (e) {
      throw Exception('Sign out failed: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during sign out.');
    }
  }

  String? get _mobileRedirectTo {
    if (kIsWeb) return null;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return AppConfig.authRedirectUrl;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
        return null;
    }
  }
}
