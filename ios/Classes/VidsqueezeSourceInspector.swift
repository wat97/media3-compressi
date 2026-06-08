import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

final class VidsqueezeSourceInspector: @unchecked Sendable {
    func inspect(url: URL) throws -> VidsqueezeSourceVideoInfo {
        guard url.isFileURL else {
            throw VidsqueezeCompressionFailure(code: .unsupportedInput, message: "Only local file URLs are supported")
        }

        let asset = AVURLAsset(url: url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VidsqueezeCompressionFailure(code: .unsupportedInput, message: "Input has no readable video track")
        }

        let transformedSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let width = Int(abs(transformedSize.width).rounded())
        let height = Int(abs(transformedSize.height).rounded())
        guard width > 0, height > 0 else {
            throw VidsqueezeCompressionFailure(code: .unsupportedInput, message: "Input video dimensions are invalid")
        }

        let formatDescription = videoTrack.formatDescriptions.first.map { $0 as! CMFormatDescription }
        let flags = inspectFormatFlags(formatDescription)
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0

        return VidsqueezeSourceVideoInfo(
            url: url,
            width: width,
            height: height,
            frameRate: videoTrack.nominalFrameRate > 0 ? Double(videoTrack.nominalFrameRate) : 30.0,
            bitrate: videoTrack.estimatedDataRate > 0 ? Int(videoTrack.estimatedDataRate.rounded()) : nil,
            durationMs: Int((asset.duration.seconds * 1000).rounded()),
            fileSizeBytes: Int64(fileSize),
            hasAudio: !asset.tracks(withMediaType: .audio).isEmpty,
            isHdr: flags.isHdr,
            isTenBit: flags.isTenBit,
            isDolbyVision: flags.isDolbyVision,
            codecSubType: formatDescription.map(CMFormatDescriptionGetMediaSubType)
        )
    }

    private func inspectFormatFlags(_ formatDescription: CMFormatDescription?) -> (isHdr: Bool, isTenBit: Bool, isDolbyVision: Bool) {
        guard let formatDescription else {
            return (false, false, false)
        }

        let subtype = CMFormatDescriptionGetMediaSubType(formatDescription)
        let isDolbyVision = subtype == FourCharCode("dvh1") || subtype == FourCharCode("dvhe")
        let extensions = (CMFormatDescriptionGetExtensions(formatDescription) as NSDictionary?) ?? [:]

        let bitsPerComponent: Int? = {
            if #available(iOS 15.0, *) {
                return (extensions[kCMFormatDescriptionExtension_BitsPerComponent] as? NSNumber)?.intValue
            }
            return nil
        }()
        let transferFunction = extensions[kCVImageBufferTransferFunctionKey] as? String
        let colorPrimaries = extensions[kCVImageBufferColorPrimariesKey] as? String

        let isHdrTransfer = transferFunction == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String)
            || transferFunction == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String)
        let isWideGamut = colorPrimaries == (kCVImageBufferColorPrimaries_ITU_R_2020 as String)

        return (
            isHdrTransfer || isWideGamut || isDolbyVision,
            (bitsPerComponent ?? 8) > 8,
            isDolbyVision
        )
    }
}

private extension FourCharCode {
    init(_ string: String) {
        self = string.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
