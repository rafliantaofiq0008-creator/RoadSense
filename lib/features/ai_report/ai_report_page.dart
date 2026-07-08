import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../data/models/ai_report.dart';
import '../../core/services/pdf_report_export_service.dart';
import '../../data/remote/road_photo_api.dart';

class AiReportPage extends StatelessWidget {
  final AiReport report;

  const AiReportPage({super.key, required this.report});

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(String? confidence) {
    if (confidence == null) return const SizedBox.shrink();
    
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (confidence.toLowerCase()) {
      case 'high':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        badgeText = 'High Confidence';
        break;
      case 'medium':
        badgeColor = Colors.orange;
        badgeIcon = Icons.warning;
        badgeText = 'Medium Confidence';
        break;
      case 'low':
      default:
        badgeColor = Colors.red;
        badgeIcon = Icons.error;
        badgeText = 'Low Confidence (Limited)';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        border: Border.all(color: badgeColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 16, color: badgeColor),
          const SizedBox(width: 8),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _splitMarkdownBlocks(String data) {
    final lines = data.split('\n');
    final List<String> blocks = [];
    StringBuffer currentBlock = StringBuffer();
    bool inTable = false;

    for (var line in lines) {
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        if (!inTable) {
          // Start of table
          if (currentBlock.isNotEmpty) {
            blocks.add(currentBlock.toString().trim());
            currentBlock.clear();
          }
          inTable = true;
        }
        currentBlock.writeln(line);
      } else {
        if (inTable) {
          // End of table
          if (currentBlock.isNotEmpty) {
            blocks.add(currentBlock.toString().trim());
            currentBlock.clear();
          }
          inTable = false;
        }
        currentBlock.writeln(line);
      }
    }
    if (currentBlock.isNotEmpty) {
      blocks.add(currentBlock.toString().trim());
    }
    return blocks;
  }

  Widget _buildScrollableMarkdown(BuildContext context, String markdownData) {
    final blocks = _splitMarkdownBlocks(markdownData);
    final styleSheet = MarkdownStyleSheet(
      h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
      h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
      h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      p: const TextStyle(fontSize: 15, height: 1.5),
      tableBorder: TableBorder.all(color: Colors.grey.shade300, width: 1),
      tableHead: const TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.black12, fontSize: 13),
      tableBody: const TextStyle(fontSize: 13),
      tableCellsPadding: const EdgeInsets.all(12),
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        final isTable = block.trim().startsWith('|') && block.trim().endsWith('|') && block.contains('---');

        if (isTable) {
          final firstLine = block.trim().split('\n').first;
          final columnCount = (firstLine.split('|').length - 2).clamp(1, 20);
          final screenWidth = MediaQuery.of(context).size.width;
          final minW = (columnCount * 140.0).clamp(screenWidth, 3000.0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minW.toDouble()),
                child: MarkdownBody(
                  data: block,
                  selectable: true,
                  styleSheet: styleSheet,
                ),
              ),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: MarkdownBody(
              data: block,
              selectable: true,
              styleSheet: styleSheet,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final confidence = report.inputSummary?['data_quality']?['data_confidence_level']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scientific Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Report',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report.reportMarkdown));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text("Generating PDF..."),
                    ],
                  ),
                ),
              );
              try {
                final photos = await RoadPhotoApi().getPhotosForSession(report.sessionId);
                await PdfReportExportService().exportReport(report, photos);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withValues(alpha: 0.05),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    'Model: ${report.modelName ?? "Unknown"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Type: ${report.reportType.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Generated: ${DateFormat('MMM d, yyyy - HH:mm').format(report.generatedAt.toLocal())}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                Text(
                  'Session ID: ${report.sessionId}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                if (report.inputSummary?['report_logic_version'] != null)
                  Text(
                    'Logic Version: ${report.inputSummary?['report_logic_version']}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildConfidenceBadge(confidence),
                    if (report.inputSummary?['road_condition_assessment']?['road_risk_level'] != null)
                      _buildInfoBadge('Risk: ${report.inputSummary?['road_condition_assessment']?['road_risk_level']}', Colors.purple),
                    if (report.inputSummary?['data_quality']?['report_validity_status'] != null)
                      _buildInfoBadge('Validity: ${report.inputSummary?['data_quality']?['report_validity_status']}', Colors.indigo),
                    if (report.inputSummary?['technical_scores']?['road_damage_score'] != null)
                      _buildInfoBadge('Damage Score: ${report.inputSummary?['technical_scores']?['road_damage_score']}', Colors.teal),
                    if (report.inputSummary?['government_workflow']?['recommended_status'] != null)
                      _buildInfoBadge('Workflow: ${report.inputSummary?['government_workflow']?['recommended_status']}', Colors.deepOrange),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Disclaimer: Laporan ini adalah indikasi berbasis sensor smartphone dan memerlukan verifikasi lapangan.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.red),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildScrollableMarkdown(context, report.reportMarkdown),
          ),
        ],
      ),
    );
  }
}
