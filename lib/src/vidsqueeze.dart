import 'dart:async';

import 'package:flutter/services.dart';

import 'models/compression_request.dart';
import 'models/compression_result.dart';
import 'models/compression_state.dart';
import 'platform/channel_contract.dart';

class Vidsqueeze {
  Vidsqueeze._();

  static final Vidsqueeze instance = Vidsqueeze._();

  static const MethodChannel _methodChannel =
      MethodChannel(VidsqueezeChannelContract.methodsChannel);
  static const EventChannel _eventChannel =
      EventChannel(VidsqueezeChannelContract.eventsChannel);

  Stream<CompressionState>? _stateStream;

  Stream<CompressionState> states() {
    return _stateStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return CompressionState.fromMap(Map<Object?, Object?>.from(event as Map));
    }).asBroadcastStream();
  }

  Future<CompressionResult> compress(CompressionRequest request) async {
    final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
      VidsqueezeChannelContract.methodCompress,
      request.toMap(),
    );
    if (result == null) {
      throw PlatformException(
        code: VidsqueezeChannelContract.errorNullResult,
        message: 'Compression finished without a result payload',
      );
    }
    return CompressionResult.fromMap(result);
  }

  Future<void> cancel(String taskId) {
    return _methodChannel.invokeMethod<void>(
      VidsqueezeChannelContract.methodCancel,
      <String, Object?>{VidsqueezeChannelContract.taskId: taskId},
    );
  }
}
