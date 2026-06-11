import 'force_codec.dart';
import '../platform/channel_contract.dart';

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
      taskId: map[VidsqueezeChannelContract.taskId] as String? ?? '',
      outputPath: map[VidsqueezeChannelContract.outputPath] as String? ?? '',
      outputSizeBytes:
          (map[VidsqueezeChannelContract.outputSizeBytes] as num?)?.toInt() ??
              0,
      sourceSizeBytes:
          (map[VidsqueezeChannelContract.sourceSizeBytes] as num?)?.toInt() ??
              0,
      durationMs:
          (map[VidsqueezeChannelContract.durationMs] as num?)?.toInt() ?? 0,
      codec: ForceCodec.fromValue(
          map[VidsqueezeChannelContract.codec] as String? ?? 'auto'),
      targetHeight:
          (map[VidsqueezeChannelContract.targetHeight] as num?)?.toInt(),
      targetBitrate:
          (map[VidsqueezeChannelContract.targetBitrate] as num?)?.toInt() ?? 0,
      attempts: (map[VidsqueezeChannelContract.attempts] as num?)?.toInt() ?? 0,
      usedOriginalSource:
          map[VidsqueezeChannelContract.usedOriginalSource] as bool? ?? false,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      VidsqueezeChannelContract.taskId: taskId,
      VidsqueezeChannelContract.outputPath: outputPath,
      VidsqueezeChannelContract.outputSizeBytes: outputSizeBytes,
      VidsqueezeChannelContract.sourceSizeBytes: sourceSizeBytes,
      VidsqueezeChannelContract.durationMs: durationMs,
      VidsqueezeChannelContract.codec: codec.value,
      VidsqueezeChannelContract.targetHeight: targetHeight,
      VidsqueezeChannelContract.targetBitrate: targetBitrate,
      VidsqueezeChannelContract.attempts: attempts,
      VidsqueezeChannelContract.usedOriginalSource: usedOriginalSource,
    };
  }
}
