import Foundation

final class VidsqueezeCompressionPolicyEngine {
    func plan(
        request: VidsqueezeCompressionRequest,
        source: VidsqueezeSourceVideoInfo,
        capability: VidsqueezeCapabilitySnapshot,
        forcedCodec: VidsqueezeOutputCodec? = nil
    ) throws -> VidsqueezeCompressionPlan {
        let codec = try forcedCodec ?? chooseCodec(source: source, capability: capability, request: request)
        let targetHeight = chooseTargetHeight(source: source, maxResolutionCap: request.maxResolutionCap)
        let targetBitrate = chooseTargetBitrate(
            source: source,
            codec: codec,
            preset: request.preset,
            targetHeight: targetHeight,
            maxBitrate: request.maxBitrate
        )

        let shouldKeepAudio = request.keepAudio && source.hasAudio

        return VidsqueezeCompressionPlan(
            codec: codec,
            targetHeight: targetHeight,
            targetBitrate: targetBitrate,
            removeAudio: !shouldKeepAudio,
            transcodeAudio: shouldKeepAudio,
            audioBitrate: shouldKeepAudio ? chooseAudioBitrate(source: source, preset: request.preset) : nil,
            progressIntervalMs: max(request.progressIntervalMs, 1)
        )
    }

    func chooseCodec(
        source: VidsqueezeSourceVideoInfo,
        capability: VidsqueezeCapabilitySnapshot,
        request: VidsqueezeCompressionRequest
    ) throws -> VidsqueezeOutputCodec {
        switch request.forceCodec {
        case .avc:
            guard capability.avcAvailable else { throw VidsqueezeCompressionPolicyError.codecUnavailable }
            return .avc
        case .hevc:
            guard request.allowHevc, capability.hevcAvailable else { throw VidsqueezeCompressionPolicyError.codecUnavailable }
            return .hevc
        case .auto:
            break
        }

        if request.allowHevc
            && capability.prefersHevc
            && capability.hevcAvailable
            && !source.isHdr
            && !source.isTenBit
            && !source.isDolbyVision {
            return .hevc
        }
        if capability.avcAvailable {
            return .avc
        }
        if capability.hevcAvailable {
            return .hevc
        }
        throw VidsqueezeCompressionPolicyError.codecUnavailable
    }

    func chooseTargetHeight(source: VidsqueezeSourceVideoInfo, maxResolutionCap: Int?) -> Int? {
        guard let cap = maxResolutionCap else { return nil }
        return source.height > cap ? (cap % 2 == 0 ? cap : cap - 1) : nil
    }

    func chooseTargetBitrate(
        source: VidsqueezeSourceVideoInfo,
        codec: VidsqueezeOutputCodec,
        preset: VidsqueezeCompressionPreset,
        targetHeight: Int?,
        maxBitrate: Int?
    ) -> Int {
        let inputBitrate = source.bitrate ?? fallbackInputBitrate(source: source)
        let scaleFactor: Double = {
            guard let targetHeight, source.height > 0 else { return 1.0 }
            return Double(targetHeight) / Double(source.height)
        }()
        let codecFactor: Double
        switch (preset, codec) {
        case (.quality, .avc): codecFactor = 0.86
        case (.quality, .hevc): codecFactor = 0.68
        case (.balanced, .avc): codecFactor = 0.72
        case (.balanced, .hevc): codecFactor = 0.56
        case (.smallSize, .avc): codecFactor = 0.54
        case (.smallSize, .hevc): codecFactor = 0.42
        }
        let fpsFactor = source.frameRate > 30 ? 1.12 : 1.0
        let computed = max(Int(Double(inputBitrate) * scaleFactor * codecFactor * fpsFactor), 1_200_000)
        return maxBitrate.map { min($0, computed) } ?? computed
    }

    private func fallbackInputBitrate(source: VidsqueezeSourceVideoInfo) -> Int {
        let pixels = max(source.width * source.height, 1)
        let fps = max(Int(source.frameRate), 30)
        return max(Int(Double(pixels * fps) * 0.12), 2_000_000)
    }

    private func chooseAudioBitrate(source: VidsqueezeSourceVideoInfo, preset: VidsqueezeCompressionPreset) -> Int {
        guard source.hasAudio else { return 0 }
        switch preset {
        case .quality:
            return 128_000
        case .balanced:
            return 96_000
        case .smallSize:
            return 64_000
        }
    }
}

enum VidsqueezeCompressionPolicyError: Error {
    case codecUnavailable
}
