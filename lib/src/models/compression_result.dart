import 'force_codec.dart';

class CompressionResult {
  const CompressionResult({
    required this.taskId,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.sourceSizeBytes,
    required this.durationMs,
    required this.codec,
    required this.targetBitrate,
    required this.attempts,
    this.targetHeight,
    this.usedOriginalSource = false,
  });

  final String taskId;
  final String outputPath;
  final int outputSizeBytes;
  final int sourceSizeBytes;
  final int durationMs;
  final ForceCodec codec;
  final int? targetHeight;
  final int targetBitrate;
  final int attempts;
  final bool usedOriginalSource;

  factory CompressionResult.fromMap(Map<Object?, Object?> map) {
    return CompressionResult(
      taskId: map['taskId'] as String? ?? '',
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: (map['outputSizeBytes'] as num?)?.toInt() ?? 0,
      sourceSizeBytes: (map['sourceSizeBytes'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      codec: ForceCodec.fromValue(map['codec'] as String? ?? 'auto'),
      targetHeight: (map['targetHeight'] as num?)?.toInt(),
      targetBitrate: (map['targetBitrate'] as num?)?.toInt() ?? 0,
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      usedOriginalSource: map['usedOriginalSource'] as bool? ?? false,
    );
  }
}

