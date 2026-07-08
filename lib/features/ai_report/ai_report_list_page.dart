import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/remote/ai_report_api.dart';
import '../../data/models/ai_report.dart';
import 'ai_report_page.dart';

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
        title: const Text('AI Scientific Reports'),
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
              ? const Center(
                  child: Text(
                    'No reports generated yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _reports.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.description, color: Colors.blue),
                        title: Text(report.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Generated: ${DateFormat('MMM d, HH:mm').format(report.generatedAt.toLocal())}'),
                            Text(
                              report.inputSummary?['input_summary_schema_version'] != null 
                                  ? 'Schema: ${report.inputSummary!['input_summary_schema_version']}' 
                                  : 'Legacy Report',
                              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          ],
                        ),
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiReportPage(report: report),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
