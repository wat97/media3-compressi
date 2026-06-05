import AVFoundation
import Foundation

final class VidsqueezeOutputValidator {
    func validate(url: URL, source: VidsqueezeSourceVideoInfo) throws {
        let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard resourceValues.isRegularFile == true else {
            throw VidsqueezeCompressionFailure(code: .validationFailed, message: "Output file missing")
        }
        guard (resourceValues.fileSize ?? 0) > 0 else {
            throw VidsqueezeCompressionFailure(code: .validationFailed, message: "Output file is empty")
        }

        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw VidsqueezeCompressionFailure(code: .validationFailed, message: "Output video track is unreadable")
        }

        let size = track.naturalSize.applying(track.preferredTransform)
        let width = Int(abs(size.width).rounded())
        let height = Int(abs(size.height).rounded())
        guard width > 0, height > 0 else {
            throw VidsqueezeCompressionFailure(code: .validationFailed, message: "Output video track is unreadable")
        }

        let durationMs = Int((asset.duration.seconds * 1000).rounded())
        guard abs(durationMs - source.durationMs) <= 1_500 else {
            throw VidsqueezeCompressionFailure(code: .validationFailed, message: "Output duration drift too large")
        }
    }
}
