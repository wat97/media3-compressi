import 'package:flutter_test/flutter_test.dart';
import 'package:vidsqueeze/vidsqueeze.dart';

void main() {
  test('compression request serializes expected values', () {
    const request = CompressionRequest(
      inputPath: 'content://video/test',
      outputDirectoryPath: '/tmp/output',
      preset: CompressionPreset.quality,
      forceCodec: ForceCodec.hevc,
      maxBitrate: 3000000,
      progressIntervalMs: 200,
    );

    final map = request.toMap();

    expect(map['preset'], 'quality');
    expect(map['forceCodec'], 'hevc');
    expect(map['maxBitrate'], 3000000);
    expect(map['progressIntervalMs'], 200);
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
  });
}
