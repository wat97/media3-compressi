final class VidsqueezeChannelContract {
  VidsqueezeChannelContract._();

  static const methodsChannel = 'vidsqueeze/methods';
  static const eventsChannel = 'vidsqueeze/events';

  static const methodCompress = 'compress';
  static const methodCancel = 'cancel';

  static const taskId = 'taskId';
  static const inputPath = 'inputPath';
  static const outputDirectoryPath = 'outputDirectoryPath';
  static const outputFileName = 'outputFileName';
  static const preset = 'preset';
  static const maxResolutionCap = 'maxResolutionCap';
  static const allowHevc = 'allowHevc';
  static const keepAudio = 'keepAudio';
  static const keepOriginalIfLarger = 'keepOriginalIfLarger';
  static const forceCodec = 'forceCodec';
  static const maxBitrate = 'maxBitrate';
  static const progressIntervalMs = 'progressIntervalMs';

  static const phase = 'phase';
  static const progressPercent = 'progressPercent';
  static const code = 'code';
  static const message = 'message';

  static const outputPath = 'outputPath';
  static const outputSizeBytes = 'outputSizeBytes';
  static const sourceSizeBytes = 'sourceSizeBytes';
  static const durationMs = 'durationMs';
  static const codec = 'codec';
  static const targetHeight = 'targetHeight';
  static const targetBitrate = 'targetBitrate';
  static const attempts = 'attempts';
  static const usedOriginalSource = 'usedOriginalSource';

  static const phasePreparing = 'preparing';
  static const phaseTranscoding = 'transcoding';
  static const phaseFinalizing = 'finalizing';
  static const phaseCompleted = 'completed';
  static const phaseFailed = 'failed';
  static const phaseCancelled = 'cancelled';

  static const errorBusy = 'busy';
  static const errorBadArgs = 'bad_args';
  static const errorBadRequest = 'bad_request';
  static const errorNullResult = 'null_result';
  static const errorNoContext = 'no_context';
  static const errorNoCompressor = 'no_compressor';
}
