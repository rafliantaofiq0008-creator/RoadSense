import 'package:flutter/material.dart';
import '../../data/remote/ai_report_api.dart';
import '../../data/models/ai_report.dart';
import 'ai_report_page.dart';
import '../../core/utils/app_date_time.dart';
import '../../shared/widgets/app_surface_card.dart';

class AiReportListPage extends StatefulWidget {
  final String sessionId;

  const AiReportListPage({super.key, required this.sessionId});

  @override
  State<AiReportListPage> createState() => _AiReportListPageState();
}

class _AiReportListPageState extends State<AiReportListPage> {
  final AiReportApi _api = AiReportApi();
  List<AiReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _api.getReportsForSession(widget.sessionId);
      if (mounted) {
        setState(() {
          _reports = reports;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteReport(String reportId) async {
    try {
      await _api.deleteReport(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted successfully')),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppSurfaceCard(
                      title: 'Belum ada laporan',
                      subtitle: 'Generate AI report dari halaman detail trip setelah data jalan terkumpul cukup.',
                      accentColor: Theme.of(context).colorScheme.secondary,
                      child: const Text('Laporan akan muncul di sini lengkap dengan waktu generate yang sudah disesuaikan ke lokal perangkat.'),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _reports.length,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: AppSurfaceCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiReportPage(report: report),
                            ),
                          );
                        },
                        title: report.title,
                        subtitle: 'Generated ${AppDateTime.formatShort(report.generatedAt)}',
                        accentColor: Theme.of(context).colorScheme.primary,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Report?'),
                                content: const Text('This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _deleteReport(report.id);
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        child: Text(
                          report.inputSummary?['input_summary_schema_version'] != null
                              ? 'Schema: ${report.inputSummary!['input_summary_schema_version']}'
                              : 'Legacy report',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
