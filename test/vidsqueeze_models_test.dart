import 'package:flutter_test/flutter_test.dart';
import 'package:vidsqueeze/vidsqueeze.dart';

void main() {
  test('compression request serializes expected values', () {
    const request = CompressionRequest(
      inputPath: 'content://video/test',
      outputDirectoryPath: '/tmp/output',
      preset: CompressionPreset.quality,
      forceCodec: ForceCodec.hevc,
      maxResolutionCap: CompressionResolutionCap.p720,
      maxBitrate: 3000000,
      progressIntervalMs: 200,
    );

    final map = request.toMap();

    expect(map['taskId'], isNull);
    expect(map['inputPath'], 'content://video/test');
    expect(map['outputDirectoryPath'], '/tmp/output');
    expect(map['preset'], 'quality');
    expect(map['forceCodec'], 'hevc');
    expect(map['maxResolutionCap'], 720);
    expect(map['maxBitrate'], 3000000);
    expect(map['progressIntervalMs'], 200);
  });

  test('resolution cap maps to native height values', () {
    expect(CompressionResolutionCap.original.height, isNull);
    expect(CompressionResolutionCap.p1080.height, 1080);
    expect(CompressionResolutionCap.fromHeight(null),
        CompressionResolutionCap.original);
    expect(CompressionResolutionCap.fromHeight(480),
        CompressionResolutionCap.p480);
    expect(CompressionResolutionCap.fromHeight(999),
        CompressionResolutionCap.p1080);
  });

  test('compression request asserts invalid values', () {
    expect(
      () => CompressionRequest(
        inputPath: '',
        outputDirectoryPath: '/tmp/output',
      ),
      throwsAssertionError,
    );

    expect(
      () => CompressionRequest(
        inputPath: 'file:///tmp/input.mp4',
        outputDirectoryPath: '/tmp/output',
        progressIntervalMs: 0,
      ),
      throwsAssertionError,
    );

    expect(
      () => CompressionRequest(
        inputPath: 'file:///tmp/input.mp4',
        outputDirectoryPath: '/tmp/output',
        maxBitrate: 0,
      ),
      throwsAssertionError,
    );
  });

  test('compression state deserializes expected values', () {
    final state = CompressionState.fromMap(<Object?, Object?>{
      'taskId': 'task-1',
      'phase': 'transcoding',
      'progressPercent': 45,
    });

    expect(state.taskId, 'task-1');
    expect(state.phase, CompressionPhase.transcoding);
    expect(state.progressPercent, 45);
    expect(state.toMap(), <String, Object?>{
      'taskId': 'task-1',
      'phase': 'transcoding',
      'progressPercent': 45,
      'code': null,
      'message': null,
    });
  });

  test('compression result roundtrips expected values', () {
    final result = CompressionResult.fromMap(<Object?, Object?>{
      'taskId': 'task-9',
      'outputPath': '/tmp/output/compressed.mp4',
      'outputSizeBytes': 1200,
      'sourceSizeBytes': 4200,
      'durationMs': 32000,
      'codec': 'hevc',
      'targetHeight': 720,
      'targetBitrate': 1400000,
      'attempts': 1,
      'usedOriginalSource': false,
    });

    expect(result.taskId, 'task-9');
    expect(result.codec, ForceCodec.hevc);
    expect(result.targetHeight, 720);
    expect(result.toMap(), <String, Object?>{
      'taskId': 'task-9',
      'outputPath': '/tmp/output/compressed.mp4',
      'outputSizeBytes': 1200,
      'sourceSizeBytes': 4200,
      'durationMs': 32000,
      'codec': 'hevc',
      'targetHeight': 720,
      'targetBitrate': 1400000,
      'attempts': 1,
      'usedOriginalSource': false,
    });
  });
}
