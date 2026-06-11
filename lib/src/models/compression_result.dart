import 'force_codec.dart';
import '../platform/channel_contract.dart';

/// Final metadata returned after a compression task completes.
class CompressionResult {
  /// Creates compression result metadata.
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

  /// Task id associated with this result.
  final String taskId;

  /// Output video path returned by the native engine.
  final String outputPath;

  /// Output file size in bytes.
  final int outputSizeBytes;

  /// Source file size in bytes.
  final int sourceSizeBytes;

  /// Source media duration in milliseconds.
  final int durationMs;

  /// Codec used by the final output path.
  final ForceCodec codec;

  /// Target output height, or `null` when original height is used.
  final int? targetHeight;

  /// Planned target bitrate in bits per second.
  final int targetBitrate;

  /// Number of native export attempts used.
  final int attempts;

  /// Whether the original source path was returned because output was larger.
  final bool usedOriginalSource;

  /// Creates a result from a platform-channel payload.
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

  /// Serializes this result to the platform-channel payload.
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
