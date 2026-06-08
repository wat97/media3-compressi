import Foundation

struct CompressionMediaSummary: Equatable {
    let fileName: String
    let width: Int
    let height: Int
    let durationMs: Int
    let sizeBytes: Int64
    let codecLabel: String
    let hasAudio: Bool
}

struct CompressionResultSummary: Equatable {
    let fileName: String
    let outputURL: URL
    let width: Int
    let height: Int
    let durationMs: Int
    let sizeBytes: Int64
    let codecLabel: String
    let targetBitrate: Int
    let attempts: Int
    let usedOriginalSource: Bool
}

struct CompressionBenchmarkSummary: Equatable {
    let elapsedMs: Int
    let sourceSizeBytes: Int64
    let outputSizeBytes: Int64
    let attempts: Int
    let usedOriginalSource: Bool

    var savedBytes: Int64 {
        max(sourceSizeBytes - outputSizeBytes, 0)
    }

    var savedPercent: Double {
        guard sourceSizeBytes > 0 else { return 0 }
        let saved = Double(sourceSizeBytes - outputSizeBytes)
        return max(saved / Double(sourceSizeBytes), 0)
    }
}
