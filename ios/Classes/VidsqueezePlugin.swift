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
        let methodChannel = FlutterMethodChannel(name: "vidsqueeze/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(name: "vidsqueeze/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "compress":
            compress(call: call, result: result)
        case "cancel":
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
            result(FlutterError(code: "busy", message: "Another compression task is already running", details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "bad_args", message: "compress expects a map payload", details: nil))
            return
        }

        let taskId = (args["taskId"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString

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
            result(FlutterError(code: failure.code.rawValue, message: failure.message, details: ["taskId": taskId]))
        } catch {
            result(FlutterError(code: "bad_request", message: error.localizedDescription, details: ["taskId": taskId]))
        }
    }

    private func cancel(call: FlutterMethodCall, result: FlutterResult) {
        let taskId = (call.arguments as? [String: Any])?["taskId"] as? String
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
                details: ["taskId": taskId]
            )
        )
    }
}

private extension Dictionary where Key == String, Value == Any {
    func toCompressionRequest(taskId: String) throws -> VidsqueezeCompressionRequest {
        guard let inputPath = self["inputPath"] as? String else {
            throw VidsqueezeCompressionFailure(code: .unsupportedInput, message: "inputPath is required")
        }
        guard let outputDirectoryPath = self["outputDirectoryPath"] as? String else {
            throw VidsqueezeCompressionFailure(code: .unsupportedInput, message: "outputDirectoryPath is required")
        }

        let outputFileName = (self["outputFileName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "compressed_\(taskId).mp4"
        let inputURL = inputPath.hasPrefix("file://") ? URL(string: inputPath) ?? URL(fileURLWithPath: inputPath) : URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputDirectoryPath, isDirectory: true).appendingPathComponent(outputFileName)

        return try VidsqueezeCompressionRequest(
            inputURL: inputURL,
            outputURL: outputURL,
            preset: VidsqueezeCompressionPreset(rawValue: (self["preset"] as? String) ?? "balanced") ?? .balanced,
            maxResolutionCap: (self["maxResolutionCap"] as? NSNumber)?.intValue ?? 1080,
            allowHevc: (self["allowHevc"] as? Bool) ?? true,
            keepAudio: (self["keepAudio"] as? Bool) ?? true,
            keepOriginalIfLarger: (self["keepOriginalIfLarger"] as? Bool) ?? true,
            forceCodec: VidsqueezeForceCodec(rawValue: (self["forceCodec"] as? String) ?? "auto") ?? .auto,
            maxBitrate: (self["maxBitrate"] as? NSNumber)?.intValue,
            progressIntervalMs: (self["progressIntervalMs"] as? NSNumber)?.intValue ?? 250
        )
    }
}

private extension VidsqueezeCompressionState {
    func toMap(taskId: String) -> [String: Any?] {
        switch self {
        case .preparing:
            return ["taskId": taskId, "phase": "preparing"]
        case .finalizing:
            return ["taskId": taskId, "phase": "finalizing"]
        case .completed:
            return ["taskId": taskId, "phase": "completed"]
        case .cancelled:
            return ["taskId": taskId, "phase": "cancelled"]
        case let .transcoding(progressPercent):
            return ["taskId": taskId, "phase": "transcoding", "progressPercent": progressPercent]
        case let .failed(code, message):
            return ["taskId": taskId, "phase": "failed", "code": code.rawValue, "message": message]
        }
    }
}

private extension VidsqueezeCompressionSuccess {
    func toMap(taskId: String) -> [String: Any?] {
        [
            "taskId": taskId,
            "outputPath": outputURL.path,
            "outputSizeBytes": outputSizeBytes,
            "sourceSizeBytes": sourceSizeBytes,
            "durationMs": durationMs,
            "codec": codec.rawValue,
            "targetHeight": targetHeight,
            "targetBitrate": targetBitrate,
            "attempts": attempts,
            "usedOriginalSource": usedOriginalSource,
        ]
    }
}
#endif
