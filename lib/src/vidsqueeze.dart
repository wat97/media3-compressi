import 'dart:async';

import 'package:flutter/services.dart';

import 'models/compression_request.dart';
import 'models/compression_result.dart';
import 'models/compression_state.dart';

class Vidsqueeze {
  Vidsqueeze._();

  static final Vidsqueeze instance = Vidsqueeze._();

  static const MethodChannel _methodChannel = MethodChannel('vidsqueeze/methods');
  static const EventChannel _eventChannel = EventChannel('vidsqueeze/events');

  Stream<CompressionState>? _stateStream;

  Stream<CompressionState> states() {
    return _stateStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return CompressionState.fromMap(Map<Object?, Object?>.from(event as Map));
    }).asBroadcastStream();
  }

  Future<CompressionResult> compress(CompressionRequest request) async {
    final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'compress',
      request.toMap(),
    );
    if (result == null) {
      throw PlatformException(
        code: 'null_result',
        message: 'Compression finished without a result payload',
      );
    }
    return CompressionResult.fromMap(result);
  }

  Future<void> cancel(String taskId) {
    return _methodChannel.invokeMethod<void>('cancel', <String, Object?>{'taskId': taskId});
  }
}

