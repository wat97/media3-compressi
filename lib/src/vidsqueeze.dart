import 'dart:async';

import 'package:flutter/services.dart';

import 'models/compression_request.dart';
import 'models/compression_result.dart';
import 'models/compression_state.dart';
import 'platform/channel_contract.dart';

/// Entry point for native video compression.
///
/// The plugin exposes a small Flutter API and delegates heavy media work to
/// Android Media3 and iOS AVFoundation.
class Vidsqueeze {
  Vidsqueeze._();

  /// Shared plugin instance.
  static final Vidsqueeze instance = Vidsqueeze._();

  static const MethodChannel _methodChannel =
      MethodChannel(VidsqueezeChannelContract.methodsChannel);
  static const EventChannel _eventChannel =
      EventChannel(VidsqueezeChannelContract.eventsChannel);

  Stream<CompressionState>? _stateStream;

  /// Broadcast stream of native compression state updates.
  ///
  /// Subscribe before calling [compress] if the UI needs early states such as
  /// [CompressionPhase.preparing].
  Stream<CompressionState> states() {
    return _stateStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return CompressionState.fromMap(Map<Object?, Object?>.from(event as Map));
    }).asBroadcastStream();
  }

  /// Starts native compression using [request].
  ///
  /// Returns final output metadata when compression completes. Throws a
  /// [PlatformException] when native validation, export, or channel handling
  /// fails.
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

  /// Requests cancellation for the compression task identified by [taskId].
  ///
  /// Cancellation is best-effort and completes when the platform channel accepts
  /// the request.
  Future<void> cancel(String taskId) {
    return _methodChannel.invokeMethod<void>(
      VidsqueezeChannelContract.methodCancel,
      <String, Object?>{VidsqueezeChannelContract.taskId: taskId},
    );
  }
}
