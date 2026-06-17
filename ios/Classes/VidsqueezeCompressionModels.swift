import AVFoundation
import CoreMedia
import Foundation

enum VidsqueezeCompressionPreset: String {
    case quality
    case balanced
    case smallSize = "small_size"
}

enum VidsqueezeForceCodec: String {
    case auto
    case avc
    case hevc
}

enum VidsqueezeOutputCodec: String {
    case avc
    case hevc

    var avFoundationCodec: AVVideoCodecType {
        switch self {
        case .avc:
            return .h264
        case .hevc:
            return .hevc
        }
    }
}

enum VidsqueezeCompressionPhase: String {
    case preparing
    case transcoding
    case finalizing
    case completed
    case failed
    case cancelled
}

enum VidsqueezeCompressionErrorCode: String {
    case unsupportedInput = "unsupported_input"
    case codecUnavailable = "codec_unavailable"
    case transformFailed = "transform_failed"
    case ioFailed = "io_failed"
    case validationFailed = "validation_failed"
    case cancelled = "cancelled"
}

struct VidsqueezeCompressionFailure: Error {
    let code: VidsqueezeCompressionErrorCode
    let message: String
    let cause: Error?

    init(code: VidsqueezeCompressionErrorCode, message: String, cause: Error? = nil) {
        self.code = code
        self.message = message
        self.cause = cause
    }
}

enum VidsqueezeCompressionState: Equatable {
    case preparing
    case transcoding(progressPercent: Int)
    case finalizing
    case completed
    case failed(code: VidsqueezeCompressionErrorCode, message: String)
    case cancelled

    var phase: VidsqueezeCompressionPhase {
        switch self {
        case .preparing:
            return .preparing
        case .transcoding:
            return .transcoding
        case .finalizing:
            return .finalizing
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        }
    }
}

protocol VidsqueezeCompressionListener: AnyObject, Sendable {
    func onStateChanged(_ state: VidsqueezeCompressionState)
    func onSuccess(_ result: VidsqueezeCompressionSuccess)
    func onFailure(_ failure: VidsqueezeCompressionFailure)
}

protocol VidsqueezeCompressionHandle: AnyObject, Sendable {
    func cancel()
}

struct VidsqueezeCompressionRequest {
    let inputURL: URL
    let outputURL: URL
    let preset: VidsqueezeCompressionPreset
    let maxResolutionCap: Int?
    let allowHevc: Bool
    let keepAudio: Bool
    let keepOriginalIfLarger: Bool
    let forceCodec: VidsqueezeForceCodec
    let maxBitrate: Int?
    let progressIntervalMs: Int

    init(
        inputURL: URL,
        outputURL: URL,
        preset: VidsqueezeCompressionPreset = .balanced,
        maxResolutionCap: Int? = 1080,
        allowHevc: Bool = true,
        keepAudio: Bool = true,
        keepOriginalIfLarger: Bool = true,
        forceCodec: VidsqueezeForceCodec = .auto,
        maxBitrate: Int? = nil,
        progressIntervalMs: Int = 250
    ) throws {
        guard Self.isSafeOutputFileName(outputURL.lastPathComponent) else {
            throw VidsqueezeCompressionFailure(
                code: .unsupportedInput,
                message: "Output file name must be a plain .mp4 file name"
            )
        }
        if let maxBitrate, maxBitrate <= 0 {
            throw VidsqueezeCompressionFailure(
                code: .unsupportedInput,
                message: "maxBitrate must be > 0 when provided"
            )
        }
        guard progressIntervalMs > 0 else {
            throw VidsqueezeCompressionFailure(
                code: .unsupportedInput,
                message: "progressIntervalMs must be > 0"
            )
        }

        self.inputURL = inputURL
        self.outputURL = outputURL
        self.preset = preset
        self.maxResolutionCap = maxResolutionCap
        self.allowHevc = allowHevc
        self.keepAudio = keepAudio
        self.keepOriginalIfLarger = keepOriginalIfLarger
        self.forceCodec = forceCodec
        self.maxBitrate = maxBitrate
        self.progressIntervalMs = progressIntervalMs
    }

    static func isSafeOutputFileName(_ fileName: String) -> Bool {
        !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && fileName != "."
            && fileName != ".."
            && !fileName.contains("/")
            && !fileName.contains("\\")
            && !fileName.contains("..")
            && !fileName.contains(":")
            && fileName.lowercased().hasSuffix(".mp4")
    }
}

struct VidsqueezeSourceVideoInfo {
    let url: URL
    let width: Int
    let height: Int
    let frameRate: Double
    let bitrate: Int?
    let durationMs: Int
    let fileSizeBytes: Int64
    let hasAudio: Bool
    let isHdr: Bool
    let isTenBit: Bool
    let isDolbyVision: Bool
    let codecSubType: FourCharCode?

    var longestEdge: Int { max(width, height) }
    var shortestEdge: Int { min(width, height) }
}

struct VidsqueezeCapabilitySnapshot {
    let prefersHevc: Bool
    let avcAvailable: Bool
    let hevcAvailable: Bool
}

struct VidsqueezeCompressionPlan: Equatable {
    let codec: VidsqueezeOutputCodec
    let targetHeight: Int?
    let targetBitrate: Int
    let removeAudio: Bool
    let transcodeAudio: Bool
    let audioBitrate: Int?
    let progressIntervalMs: Int
}

struct VidsqueezeCompressionSuccess: Equatable {
    let outputURL: URL
    let outputSizeBytes: Int64
    let sourceSizeBytes: Int64
    let durationMs: Int
    let codec: VidsqueezeOutputCodec
    let targetHeight: Int?
    let targetBitrate: Int
    let attempts: Int
    let usedOriginalSource: Bool
}
