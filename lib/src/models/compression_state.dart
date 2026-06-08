import '../platform/channel_contract.dart';

enum CompressionPhase {
  preparing(VidsqueezeChannelContract.phasePreparing),
  transcoding(VidsqueezeChannelContract.phaseTranscoding),
  finalizing(VidsqueezeChannelContract.phaseFinalizing),
  completed(VidsqueezeChannelContract.phaseCompleted),
  failed(VidsqueezeChannelContract.phaseFailed),
  cancelled(VidsqueezeChannelContract.phaseCancelled);

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
      taskId: map[VidsqueezeChannelContract.taskId] as String? ?? '',
      phase: CompressionPhase.fromValue(
        map[VidsqueezeChannelContract.phase] as String? ?? VidsqueezeChannelContract.phaseFailed,
      ),
      progressPercent: (map[VidsqueezeChannelContract.progressPercent] as num?)?.toInt(),
      code: map[VidsqueezeChannelContract.code] as String?,
      message: map[VidsqueezeChannelContract.message] as String?,
    );
  }

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
