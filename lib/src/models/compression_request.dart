import 'compression_preset.dart';
import 'compression_resolution_cap.dart';
import 'force_codec.dart';
import '../platform/channel_contract.dart';

class CompressionRequest {
  const CompressionRequest({
    required this.inputPath,
    required this.outputDirectoryPath,
    this.outputFileName,
    this.preset = CompressionPreset.balanced,
    this.maxResolutionCap = CompressionResolutionCap.p1080,
    this.allowHevc = true,
    this.keepAudio = true,
    this.keepOriginalIfLarger = true,
    this.forceCodec = ForceCodec.auto,
    this.maxBitrate,
    this.progressIntervalMs = 250,
    this.taskId,
  })  : assert(inputPath != ''),
        assert(outputDirectoryPath != ''),
        assert(outputFileName == null || outputFileName != ''),
        assert(maxBitrate == null || maxBitrate > 0),
        assert(progressIntervalMs > 0);

  final String inputPath;
  final String outputDirectoryPath;
  final String? outputFileName;
  final CompressionPreset preset;
  final CompressionResolutionCap maxResolutionCap;
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
      VidsqueezeChannelContract.maxResolutionCap: maxResolutionCap.height,
      VidsqueezeChannelContract.allowHevc: allowHevc,
      VidsqueezeChannelContract.keepAudio: keepAudio,
      VidsqueezeChannelContract.keepOriginalIfLarger: keepOriginalIfLarger,
      VidsqueezeChannelContract.forceCodec: forceCodec.value,
      VidsqueezeChannelContract.maxBitrate: maxBitrate,
      VidsqueezeChannelContract.progressIntervalMs: progressIntervalMs,
    };
  }
}
