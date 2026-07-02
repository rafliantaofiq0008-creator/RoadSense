import 'package:flutter/material.dart';
import 'app.dart';
import 'data/remote/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const RoadSenseApp());
}
