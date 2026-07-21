import 'package:flutter/material.dart';
import 'dart:ui';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'RoadSense runtime',
        context: ErrorDescription('while handling an uncaught platform error'),
      ),
    );
    return true;
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _FatalStartupScreen(message: details.exceptionAsString());
  };
  runApp(const RoadSenseApp());
}

class _FatalStartupScreen extends StatelessWidget {
  final String message;

  const _FatalStartupScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EE),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD6E0E3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFADBD5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFB2412D),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'RoadSense mengalami error startup',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF18313C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Jika layar ini muncul, berarti aplikasi gagal menggambar halaman utama dan error sudah berhasil ditangkap.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: Color(0xFF4C646D),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SelectableText(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF18313C),
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
