import 'compression_preset.dart';
import 'compression_resolution_cap.dart';
import 'force_codec.dart';
import '../platform/channel_contract.dart';

/// Platform-neutral request for one video compression task.
///
/// The request is serialized to the method-channel contract and interpreted by
/// the Android or iOS native engine.
class CompressionRequest {
  /// Creates a compression request.
  ///
  /// [inputPath] must point to a readable local video file or platform-supported
  /// URI. [outputDirectoryPath] must be writable by the app.
  CompressionRequest({
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
  }) {
    if (inputPath.trim().isEmpty) {
      throw ArgumentError.value(inputPath, 'inputPath', 'must not be empty');
    }
    if (outputDirectoryPath.trim().isEmpty) {
      throw ArgumentError.value(
        outputDirectoryPath,
        'outputDirectoryPath',
        'must not be empty',
      );
    }
    _validateOutputFileName(outputFileName);
    if (maxBitrate != null && maxBitrate! <= 0) {
      throw ArgumentError.value(
        maxBitrate,
        'maxBitrate',
        'must be greater than zero',
      );
    }
    if (progressIntervalMs <= 0) {
      throw ArgumentError.value(
        progressIntervalMs,
        'progressIntervalMs',
        'must be greater than zero',
      );
    }
  }

  /// Local input video path or URI.
  final String inputPath;

  /// Writable output directory path.
  final String outputDirectoryPath;

  /// Optional output file name.
  final String? outputFileName;

  /// Quality/size policy preset.
  final CompressionPreset preset;

  /// Maximum output height cap.
  final CompressionResolutionCap maxResolutionCap;

  /// Whether HEVC may be selected when safe and supported.
  final bool allowHevc;

  /// Whether source audio should be preserved.
  final bool keepAudio;

  /// Whether original source should be returned when compressed output is larger.
  final bool keepOriginalIfLarger;

  /// Codec policy override.
  final ForceCodec forceCodec;

  /// Optional maximum target bitrate in bits per second.
  final int? maxBitrate;

  /// Native progress throttle interval in milliseconds.
  final int progressIntervalMs;

  /// Optional caller-visible task id used for progress and cancellation.
  final String? taskId;

  /// Serializes this request to the platform-channel payload.
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

  static void _validateOutputFileName(String? outputFileName) {
    if (outputFileName == null) return;
    if (outputFileName.trim().isEmpty) {
      throw ArgumentError.value(
        outputFileName,
        'outputFileName',
        'must not be empty',
      );
    }
    if (outputFileName == '.' || outputFileName == '..') {
      throw ArgumentError.value(
        outputFileName,
        'outputFileName',
        'must be a file name, not a path segment',
      );
    }
    if (outputFileName.contains('/') ||
        outputFileName.contains(r'\') ||
        outputFileName.contains('..') ||
        outputFileName.contains(':')) {
      throw ArgumentError.value(
        outputFileName,
        'outputFileName',
        'must be a plain file name without path traversal',
      );
    }
    if (!outputFileName.toLowerCase().endsWith('.mp4')) {
      throw ArgumentError.value(
        outputFileName,
        'outputFileName',
        'must end with .mp4',
      );
    }
  }
}
