#if canImport(UIKit) && canImport(Flutter)
import Flutter
import Foundation
import UIKit

public final class VidsqueezePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let compressor = VidsqueezeVideoCompressor()
    private var eventSink: FlutterEventSink?
    private var activeTaskId: String?
    private var activeHandle: VidsqueezeCompressionHandle?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VidsqueezePlugin()
        let methodChannel = FlutterMethodChannel(
            name: FlutterContract.methodsChannel,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: FlutterContract.eventsChannel,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case FlutterContract.methodCompress:
            compress(call: call, result: result)
        case FlutterContract.methodCancel:
            cancel(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func compress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard activeHandle == nil else {
            result(
                FlutterError(
                    code: FlutterContract.errorBusy,
                    message: "Another compression task is already running",
                    details: nil
                )
            )
            return
        }
        guard let args = call.arguments as? [String: Any] else {
            result(
                FlutterError(
                    code: FlutterContract.errorBadArgs,
                    message: "compress expects a map payload",
                    details: nil
                )
            )
            return
        }

        let taskId = args.stringValue(for: FlutterContract.keyTaskId)?
            .nonEmpty
            ?? UUID().uuidString

        do {
            let request = try args.toCompressionRequest(taskId: taskId)
            let listener = PluginCompressionListener(taskId: taskId, result: result) { [weak self] payload in
                self?.eventSink?(payload)
            } onComplete: { [weak self] in
                self?.activeHandle = nil
                self?.activeTaskId = nil
            }

            activeTaskId = taskId
            activeHandle = compressor.start(request: request, listener: listener)
        } catch let failure as VidsqueezeCompressionFailure {
            result(
                FlutterError(
                    code: failure.code.rawValue,
                    message: failure.message,
                    details: [FlutterContract.keyTaskId: taskId]
                )
            )
        } catch {
            result(
                FlutterError(
                    code: FlutterContract.errorBadRequest,
                    message: error.localizedDescription,
                    details: [FlutterContract.keyTaskId: taskId]
                )
            )
        }
    }

    private func cancel(call: FlutterMethodCall, result: FlutterResult) {
        let taskId = (call.arguments as? [String: Any])?.stringValue(for: FlutterContract.keyTaskId)
        if taskId == nil || taskId == activeTaskId {
            activeHandle?.cancel()
            activeHandle = nil
            activeTaskId = nil
        }
        result(nil)
    }
}

private final class PluginCompressionListener: NSObject, VidsqueezeCompressionListener, @unchecked Sendable {
    private let taskId: String
    private let result: FlutterResult
    private let emitState: ([String: Any?]) -> Void
    private let onComplete: () -> Void
    private var didComplete = false

    init(
        taskId: String,
        result: @escaping FlutterResult,
        emitState: @escaping ([String: Any?]) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.taskId = taskId
        self.result = result
        self.emitState = emitState
        self.onComplete = onComplete
    }

    func onStateChanged(_ state: VidsqueezeCompressionState) {
        emitState(state.toMap(taskId: taskId))
    }

    func onSuccess(_ resultValue: VidsqueezeCompressionSuccess) {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
        result(resultValue.toMap(taskId: taskId))
    }

    func onFailure(_ failure: VidsqueezeCompressionFailure) {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
        result(
            FlutterError(
                code: failure.code.rawValue,
                message: failure.message,
                details: [FlutterContract.keyTaskId: taskId]
            )
        )
    }
}

private extension Dictionary where Key == String, Value == Any {
    func toCompressionRequest(taskId: String) throws -> VidsqueezeCompressionRequest {
        guard let inputPath = stringValue(for: FlutterContract.keyInputPath) else {
            throw VidsqueezeCompressionFailure(
                code: .unsupportedInput,
                message: "\(FlutterContract.keyInputPath) is required"
            )
        }
        guard let outputDirectoryPath = stringValue(for: FlutterContract.keyOutputDirectoryPath) else {
            throw VidsqueezeCompressionFailure(
                code: .unsupportedInput,
                message: "\(FlutterContract.keyOutputDirectoryPath) is required"
            )
        }

        let outputFileName = stringValue(for: FlutterContract.keyOutputFileName)?.nonEmpty
            ?? "compressed_\(taskId).mp4"
        let inputURL = inputPath.toPlatformURL()
        let outputURL = outputDirectoryPath
            .toPlatformURL(isDirectory: true)
            .appendingPathComponent(outputFileName)

        return try VidsqueezeCompressionRequest(
            inputURL: inputURL,
            outputURL: outputURL,
            preset: VidsqueezeCompressionPreset(rawValue: stringValue(for: FlutterContract.keyPreset) ?? "balanced") ?? .balanced,
            maxResolutionCap: (self[FlutterContract.keyMaxResolutionCap] as? NSNumber)?.intValue,
            allowHevc: self[FlutterContract.keyAllowHevc] as? Bool ?? true,
            keepAudio: self[FlutterContract.keyKeepAudio] as? Bool ?? true,
            keepOriginalIfLarger: self[FlutterContract.keyKeepOriginalIfLarger] as? Bool ?? true,
            forceCodec: VidsqueezeForceCodec(rawValue: stringValue(for: FlutterContract.keyForceCodec) ?? "auto") ?? .auto,
            maxBitrate: (self[FlutterContract.keyMaxBitrate] as? NSNumber)?.intValue,
            progressIntervalMs: (self[FlutterContract.keyProgressIntervalMs] as? NSNumber)?.intValue ?? 250
        )
    }

    func stringValue(for key: String) -> String? {
        self[key] as? String
    }
}

private extension VidsqueezeCompressionState {
    func toMap(taskId: String) -> [String: Any?] {
        switch self {
        case .preparing:
            return [
                FlutterContract.keyTaskId: taskId,
                FlutterContract.keyPhase: FlutterContract.phasePreparing,
            ]
        case .finalizing:
            return [
                FlutterContract.keyTaskId: taskId,
                FlutterContract.keyPhase: FlutterContract.phaseFinalizing,
            ]
        case .completed:
            return [
                FlutterContract.keyTaskId: taskId,
                FlutterContract.keyPhase: FlutterContract.phaseCompleted,
            ]
        case .cancelled:
            return [
                FlutterContract.keyTaskId: taskId,
                FlutterContract.keyPhase: FlutterContract.phaseCancelled,
            ]
        case let .transcoding(progressPercent):
            return [
                FlutterContract.keyTaskId: taskId,
                FlutterContract.keyPhase: FlutterContract.phaseTranscoding,
                FlutterContract.keyProgressPercent: progressPercent,
            ]
        case let .failed(code, message):
            return [
                FlutterContract.keyTaskId: taskId,
                FlutterContract.keyPhase: FlutterContract.phaseFailed,
                FlutterContract.keyCode: code.rawValue,
                FlutterContract.keyMessage: message,
            ]
        }
    }
}

private extension VidsqueezeCompressionSuccess {
    func toMap(taskId: String) -> [String: Any?] {
        [
            FlutterContract.keyTaskId: taskId,
            FlutterContract.keyOutputPath: outputURL.path,
            FlutterContract.keyOutputSizeBytes: outputSizeBytes,
            FlutterContract.keySourceSizeBytes: sourceSizeBytes,
            FlutterContract.keyDurationMs: durationMs,
            FlutterContract.keyCodec: codec.rawValue,
            FlutterContract.keyTargetHeight: targetHeight,
            FlutterContract.keyTargetBitrate: targetBitrate,
            FlutterContract.keyAttempts: attempts,
            FlutterContract.keyUsedOriginalSource: usedOriginalSource,
        ]
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }

    func toPlatformURL(isDirectory: Bool = false) -> URL {
        if hasPrefix("file://"), let url = URL(string: self) {
            return url
        }
        return URL(fileURLWithPath: self, isDirectory: isDirectory)
    }
}

private enum FlutterContract {
    static let methodsChannel = "vidsqueeze/methods"
    static let eventsChannel = "vidsqueeze/events"

    static let methodCompress = "compress"
    static let methodCancel = "cancel"

    static let keyTaskId = "taskId"
    static let keyInputPath = "inputPath"
    static let keyOutputDirectoryPath = "outputDirectoryPath"
    static let keyOutputFileName = "outputFileName"
    static let keyPreset = "preset"
    static let keyMaxResolutionCap = "maxResolutionCap"
    static let keyAllowHevc = "allowHevc"
    static let keyKeepAudio = "keepAudio"
    static let keyKeepOriginalIfLarger = "keepOriginalIfLarger"
    static let keyForceCodec = "forceCodec"
    static let keyMaxBitrate = "maxBitrate"
    static let keyProgressIntervalMs = "progressIntervalMs"
    static let keyPhase = "phase"
    static let keyProgressPercent = "progressPercent"
    static let keyCode = "code"
    static let keyMessage = "message"
    static let keyOutputPath = "outputPath"
    static let keyOutputSizeBytes = "outputSizeBytes"
    static let keySourceSizeBytes = "sourceSizeBytes"
    static let keyDurationMs = "durationMs"
    static let keyCodec = "codec"
    static let keyTargetHeight = "targetHeight"
    static let keyTargetBitrate = "targetBitrate"
    static let keyAttempts = "attempts"
    static let keyUsedOriginalSource = "usedOriginalSource"

    static let phasePreparing = "preparing"
    static let phaseTranscoding = "transcoding"
    static let phaseFinalizing = "finalizing"
    static let phaseCompleted = "completed"
    static let phaseFailed = "failed"
    static let phaseCancelled = "cancelled"

    static let errorBusy = "busy"
    static let errorBadArgs = "bad_args"
    static let errorBadRequest = "bad_request"
}
#endif
