import 'compression_preset.dart';
import 'force_codec.dart';

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
      'taskId': taskId,
      'inputPath': inputPath,
      'outputDirectoryPath': outputDirectoryPath,
      'outputFileName': outputFileName,
      'preset': preset.value,
      'maxResolutionCap': maxResolutionCap,
      'allowHevc': allowHevc,
      'keepAudio': keepAudio,
      'keepOriginalIfLarger': keepOriginalIfLarger,
      'forceCodec': forceCodec.value,
      'maxBitrate': maxBitrate,
      'progressIntervalMs': progressIntervalMs,
    };
  }
}

