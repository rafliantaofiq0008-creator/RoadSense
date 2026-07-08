class AiReport {
  final String id;
  final String userId;
  final String sessionId;
  final String title;
  final String reportType;
  final String status;
  final Map<String, dynamic>? inputSummary;
  final String reportMarkdown;
  final String? modelName;
  final DateTime generatedAt;
  final DateTime createdAt;

  AiReport({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.title,
    required this.reportType,
    required this.status,
    this.inputSummary,
    required this.reportMarkdown,
    this.modelName,
    required this.generatedAt,
    required this.createdAt,
  });

  factory AiReport.fromMap(Map<String, dynamic> map) {
    return AiReport(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sessionId: map['session_id'] as String,
      title: map['title'] as String,
      reportType: map['report_type'] as String,
      status: map['status'] as String,
      inputSummary: map['input_summary'] as Map<String, dynamic>?,
      reportMarkdown: map['report_markdown'] as String,
      modelName: map['model_name'] as String?,
      generatedAt: DateTime.parse(map['generated_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'title': title,
      'report_type': reportType,
      'status': status,
      'input_summary': inputSummary,
      'report_markdown': reportMarkdown,
      'model_name': modelName,
      'generated_at': generatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
