import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_report.dart';

class AiReportApi {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AiReport> generateReportForSession(String sessionId) async {
    try {
      final response = await _client.functions.invoke(
        'generate-road-report',
        body: {
          'session_id': sessionId,
        },
      );
      
      if (response.status != 200) {
        throw Exception('Failed to generate report: ${response.data}');
      }
      
      final reportId = response.data['report_id'] as String;
      return getReportById(reportId);
    } catch (e) {
      throw Exception('Failed to invoke edge function: $e');
    }
  }

  Future<List<AiReport>> getReportsForSession(String sessionId) async {
    try {
      final response = await _client
          .from('ai_reports')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);
      
      return (response as List).map((e) => AiReport.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reports: $e');
    }
  }

  Future<AiReport> getReportById(String reportId) async {
    try {
      final response = await _client
          .from('ai_reports')
          .select()
          .eq('id', reportId)
          .single();
      
      return AiReport.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch report: $e');
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      await _client.from('ai_reports').delete().eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }
}
