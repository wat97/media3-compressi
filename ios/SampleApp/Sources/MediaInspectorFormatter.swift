import Foundation

enum MediaInspectorFormatter {
    static func megabytes(_ bytes: Int64) -> String {
        let value = Double(bytes) / 1_048_576
        return String(format: "%.2f MB", value)
    }

    static func duration(_ durationMs: Int) -> String {
        let totalSeconds = max(durationMs / 1000, 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func dimensions(width: Int, height: Int) -> String {
        "\(width)x\(height)"
    }

    static func bitrate(_ bitrate: Int) -> String {
        guard bitrate > 0 else { return "-" }
        let mbps = Double(bitrate) / 1_000_000
        return String(format: "%.2f Mbps", mbps)
    }

    static func savedPercent(sourceBytes: Int64, outputBytes: Int64) -> String {
        guard sourceBytes > 0 else { return "0%" }
        let percent = max((Double(sourceBytes - outputBytes) / Double(sourceBytes)) * 100, 0)
        return String(format: "%.1f%%", percent)
    }

    static func codecLabel(for codec: VidsqueezeOutputCodec) -> String {
        switch codec {
        case .avc:
            return "AVC / H.264"
        case .hevc:
            return "HEVC / H.265"
        }
    }

    static func codecLabel(for source: VidsqueezeSourceVideoInfo) -> String {
        guard let subtype = source.codecSubType else { return "Unknown" }
        switch subtype {
        case FourCharCode("avc1"), FourCharCode("h264"):
            return "AVC / H.264"
        case FourCharCode("hvc1"), FourCharCode("hev1"):
            return "HEVC / H.265"
        case FourCharCode("dvh1"), FourCharCode("dvhe"):
            return "Dolby Vision"
        default:
            return "0x" + String(subtype, radix: 16)
        }
    }
}

private extension FourCharCode {
    init(_ string: String) {
        self = string.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
