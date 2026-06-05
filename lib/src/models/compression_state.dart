enum CompressionPhase {
  preparing('preparing'),
  transcoding('transcoding'),
  finalizing('finalizing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const CompressionPhase(this.value);

  final String value;

  static CompressionPhase fromValue(String value) {
    return CompressionPhase.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CompressionPhase.failed,
    );
  }
}

class CompressionState {
  const CompressionState({
    required this.taskId,
    required this.phase,
    this.progressPercent,
    this.code,
    this.message,
  });

  final String taskId;
  final CompressionPhase phase;
  final int? progressPercent;
  final String? code;
  final String? message;

  factory CompressionState.fromMap(Map<Object?, Object?> map) {
    return CompressionState(
      taskId: map['taskId'] as String? ?? '',
      phase: CompressionPhase.fromValue(map['phase'] as String? ?? 'failed'),
      progressPercent: (map['progressPercent'] as num?)?.toInt(),
      code: map['code'] as String?,
      message: map['message'] as String?,
    );
  }
}

