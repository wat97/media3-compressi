import 'compression_preset.dart';
import 'force_codec.dart';
import '../platform/channel_contract.dart';

class CompressionRequest {
  const CompressionRequest({
    required this.inputPath,
    required this.outputDirectoryPath,
    this.outputFileName,
    this.preset = CompressionPreset.balanced,
    this.maxResolutionCap,
    this.allowHevc = true,
    this.keepAudio = true,
    this.keepOriginalIfLarger = true,
    this.forceCodec = ForceCodec.auto,
    this.maxBitrate,
    this.progressIntervalMs = 250,
    this.taskId,
  });

  final String inputPath;
  final String outputDirectoryPath;
  final String? outputFileName;
  final CompressionPreset preset;
  final int? maxResolutionCap;
  final bool allowHevc;
  final bool keepAudio;
  final bool keepOriginalIfLarger;
  final ForceCodec forceCodec;
  final int? maxBitrate;
  final int progressIntervalMs;
  final String? taskId;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      VidsqueezeChannelContract.taskId: taskId,
      VidsqueezeChannelContract.inputPath: inputPath,
      VidsqueezeChannelContract.outputDirectoryPath: outputDirectoryPath,
      VidsqueezeChannelContract.outputFileName: outputFileName,
      VidsqueezeChannelContract.preset: preset.value,
      VidsqueezeChannelContract.maxResolutionCap: maxResolutionCap,
      VidsqueezeChannelContract.allowHevc: allowHevc,
      VidsqueezeChannelContract.keepAudio: keepAudio,
      VidsqueezeChannelContract.keepOriginalIfLarger: keepOriginalIfLarger,
      VidsqueezeChannelContract.forceCodec: forceCodec.value,
      VidsqueezeChannelContract.maxBitrate: maxBitrate,
      VidsqueezeChannelContract.progressIntervalMs: progressIntervalMs,
    };
  }
}
