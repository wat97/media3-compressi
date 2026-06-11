import '../platform/channel_contract.dart';

/// Compression lifecycle phase emitted by [CompressionState].
enum CompressionPhase {
  /// Native engine is inspecting source and preparing encoder settings.
  preparing(VidsqueezeChannelContract.phasePreparing),

  /// Native engine is actively transcoding video frames.
  transcoding(VidsqueezeChannelContract.phaseTranscoding),

  /// Native engine is finalizing and validating output.
  finalizing(VidsqueezeChannelContract.phaseFinalizing),

  /// Compression completed successfully.
  completed(VidsqueezeChannelContract.phaseCompleted),

  /// Compression failed.
  failed(VidsqueezeChannelContract.phaseFailed),

  /// Compression was cancelled.
  cancelled(VidsqueezeChannelContract.phaseCancelled);

  const CompressionPhase(this.value);

  /// Serialized value sent through the platform channel.
  final String value;

  /// Creates a phase from a serialized platform-channel [value].
  static CompressionPhase fromValue(String value) {
    return CompressionPhase.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CompressionPhase.failed,
    );
  }
}

/// Progress or terminal state emitted by native compression.
class CompressionState {
  /// Creates a compression state event.
  const CompressionState({
    required this.taskId,
    required this.phase,
    this.progressPercent,
    this.code,
    this.message,
  });

  /// Task id associated with this state.
  final String taskId;

  /// Current compression lifecycle phase.
  final CompressionPhase phase;

  /// Progress from 0 to 100 for [CompressionPhase.transcoding].
  final int? progressPercent;

  /// Native/domain error code when [phase] is [CompressionPhase.failed].
  final String? code;

  /// Human-readable native/domain failure message.
  final String? message;

  /// Creates a state from a platform-channel payload.
  factory CompressionState.fromMap(Map<Object?, Object?> map) {
    return CompressionState(
      taskId: map[VidsqueezeChannelContract.taskId] as String? ?? '',
      phase: CompressionPhase.fromValue(
        map[VidsqueezeChannelContract.phase] as String? ??
            VidsqueezeChannelContract.phaseFailed,
      ),
      progressPercent:
          (map[VidsqueezeChannelContract.progressPercent] as num?)?.toInt(),
      code: map[VidsqueezeChannelContract.code] as String?,
      message: map[VidsqueezeChannelContract.message] as String?,
    );
  }

  /// Serializes this state to the platform-channel payload.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      VidsqueezeChannelContract.taskId: taskId,
      VidsqueezeChannelContract.phase: phase.value,
      VidsqueezeChannelContract.progressPercent: progressPercent,
      VidsqueezeChannelContract.code: code,
      VidsqueezeChannelContract.message: message,
    };
  }
}
