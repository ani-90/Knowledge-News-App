class PipelineRun {
  final String runId;
  final String status;
  final int? articlesAdded;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const PipelineRun({
    required this.runId,
    required this.status,
    this.articlesAdded,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  factory PipelineRun.fromJson(Map<String, dynamic> json) => PipelineRun(
        runId: json['run_id'] as String,
        status: json['status'] as String,
        articlesAdded: json['persisted_count'] as int?,
        errorMessage: null,
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : DateTime.now(),
        completedAt: json['finished_at'] != null
            ? DateTime.parse(json['finished_at'] as String)
            : null,
      );

  bool get isRunning => status == 'running';
  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
}
