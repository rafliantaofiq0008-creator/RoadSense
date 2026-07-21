import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/supabase_service.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'services/auth_service.dart';

class RoadSenseApp extends StatelessWidget {
  const RoadSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _BootstrapGate(),
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  static const _startupTimeout = Duration(seconds: 12);

  Future<String?>? _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _bootstrapFuture = _initializeApp();
      });
    });
  }

  Future<String?> _initializeApp() async {
    try {
      await SupabaseService.initialize().timeout(_startupTimeout);
      return null;
    } on TimeoutException {
      return 'Inisialisasi aplikasi melebihi batas waktu ${_startupTimeout.inSeconds} detik. '
          'Kemungkinan layanan startup macet di perangkat ini. Coba tekan "Muat Ulang" atau buka ulang aplikasi.';
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'RoadSense bootstrap',
          context: ErrorDescription(
            'while initializing Supabase after app startup',
          ),
        ),
      );
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  void _retryBootstrap() {
    setState(() {
      _bootstrapFuture = _initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapFuture = _bootstrapFuture;
    if (bootstrapFuture == null) {
      return const _BootstrapLoadingPage(
        title: 'Menyalakan antarmuka RoadSense',
        message:
            'Tampilan utama dimunculkan lebih dulu agar startup tetap stabil di perangkat Android.',
      );
    }

    return FutureBuilder<String?>(
      future: bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapLoadingPage();
        }

        final startupError = snapshot.data;
        if (startupError != null) {
          return _StartupFailurePage(
            message: startupError,
            onRetry: _retryBootstrap,
          );
        }

        return StreamBuilder<AuthState>(
          stream: AuthService().authStateChanges,
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const _BootstrapLoadingPage(
                title: 'Menyiapkan sesi pengguna',
                message:
                    'RoadSense sedang memulihkan login dan sinkronisasi cloud.',
              );
            }

            final session = authSnapshot.data?.session;
            if (session != null) {
              return const DashboardPage();
            }
            return const LoginPage();
          },
        );
      },
    );
  }
}

class _BootstrapLoadingPage extends StatelessWidget {
  final String title;
  final String message;

  const _BootstrapLoadingPage({
    this.title = 'Mempersiapkan RoadSense',
    this.message =
        'Aplikasi sedang memuat layanan inti, GPS, dan koneksi cloud.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      size: 42,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupFailurePage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StartupFailurePage({required this.message, required this.onRetry});

  bool get _looksLikeMissingSupabaseConfig =>
      message.contains('Supabase configuration is missing');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.72,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        color: theme.colorScheme.error,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'RoadSense tidak bisa memulai aplikasi',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _looksLikeMissingSupabaseConfig
                          ? 'Build Android ini belum membawa konfigurasi Supabase, jadi layar login/dashboard tidak bisa dimuat.'
                          : 'Terjadi masalah saat inisialisasi aplikasi sebelum halaman utama tampil.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: SelectableText(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_looksLikeMissingSupabaseConfig)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Build ulang APK/AAB dengan SUPABASE_URL dan SUPABASE_ANON_KEY. Jika release dibuat tanpa dart-define, aplikasi akan gagal startup.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.45,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Muat Ulang'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
