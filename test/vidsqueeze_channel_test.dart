import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidsqueeze/vidsqueeze.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('vidsqueeze/methods');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() async {
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  test('compress sends request over method channel and parses result', () async {
    late MethodCall capturedCall;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      capturedCall = call;
      return <String, Object?>{
        'taskId': 'task-42',
        'outputPath': '/tmp/output.mp4',
        'outputSizeBytes': 1024,
        'sourceSizeBytes': 4096,
        'durationMs': 1500,
        'codec': 'avc',
        'targetHeight': 720,
        'targetBitrate': 1400000,
        'attempts': 1,
        'usedOriginalSource': false,
      };
    });

    final result = await Vidsqueeze.instance.compress(
      const CompressionRequest(
        taskId: 'task-42',
        inputPath: 'file:///tmp/input.mp4',
        outputDirectoryPath: '/tmp',
        outputFileName: 'output.mp4',
        preset: CompressionPreset.smallSize,
        maxResolutionCap: 720,
        allowHevc: false,
        keepAudio: false,
        keepOriginalIfLarger: false,
        forceCodec: ForceCodec.avc,
        maxBitrate: 1400000,
        progressIntervalMs: 500,
      ),
    );

    expect(capturedCall.method, 'compress');
    expect(capturedCall.arguments, <String, Object?>{
      'taskId': 'task-42',
      'inputPath': 'file:///tmp/input.mp4',
      'outputDirectoryPath': '/tmp',
      'outputFileName': 'output.mp4',
      'preset': 'small_size',
      'maxResolutionCap': 720,
      'allowHevc': false,
      'keepAudio': false,
      'keepOriginalIfLarger': false,
      'forceCodec': 'avc',
      'maxBitrate': 1400000,
      'progressIntervalMs': 500,
    });
    expect(result.taskId, 'task-42');
    expect(result.codec, ForceCodec.avc);
    expect(result.outputPath, '/tmp/output.mp4');
  });

  test('cancel sends task id over method channel', () async {
    late MethodCall capturedCall;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      capturedCall = call;
      return null;
    });

    await Vidsqueeze.instance.cancel('task-cancel');

    expect(capturedCall.method, 'cancel');
    expect(capturedCall.arguments, <String, Object?>{
      'taskId': 'task-cancel',
    });
  });
}
