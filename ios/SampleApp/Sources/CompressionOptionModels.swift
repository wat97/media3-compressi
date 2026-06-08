import Foundation

enum CompressionPresetOption: String, CaseIterable, Identifiable {
    case quality
    case balanced
    case smallSize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quality:
            return "Quality"
        case .balanced:
            return "Balanced"
        case .smallSize:
            return "Small Size"
        }
    }

    var nativeValue: VidsqueezeCompressionPreset {
        switch self {
        case .quality:
            return .quality
        case .balanced:
            return .balanced
        case .smallSize:
            return .smallSize
        }
    }
}

enum ResolutionCapOption: String, CaseIterable, Identifiable {
    case original
    case p2160
    case p1440
    case p1080
    case p720
    case p540
    case p480

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .p2160:
            return "2160p"
        case .p1440:
            return "1440p"
        case .p1080:
            return "1080p"
        case .p720:
            return "720p"
        case .p540:
            return "540p"
        case .p480:
            return "480p"
        }
    }

    var nativeValue: Int? {
        switch self {
        case .original:
            return nil
        case .p2160:
            return 2160
        case .p1440:
            return 1440
        case .p1080:
            return 1080
        case .p720:
            return 720
        case .p540:
            return 540
        case .p480:
            return 480
        }
    }
}

enum ForceCodecOption: String, CaseIterable, Identifiable {
    case auto
    case avc
    case hevc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .avc:
            return "AVC / H.264"
        case .hevc:
            return "HEVC / H.265"
        }
    }

    var nativeValue: VidsqueezeForceCodec {
        switch self {
        case .auto:
            return .auto
        case .avc:
            return .avc
        case .hevc:
            return .hevc
        }
    }
}
