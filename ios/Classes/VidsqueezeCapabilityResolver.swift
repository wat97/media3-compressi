import CoreMedia
import Foundation
import VideoToolbox

final class VidsqueezeCapabilityResolver {
    private var cached: VidsqueezeCapabilitySnapshot?

    func resolve() -> VidsqueezeCapabilitySnapshot {
        if let cached {
            return cached
        }

        let hevcAvailable = encoderAvailable(codec: kCMVideoCodecType_HEVC)
        let snapshot = VidsqueezeCapabilitySnapshot(
            prefersHevc: hevcAvailable,
            avcAvailable: encoderAvailable(codec: kCMVideoCodecType_H264),
            hevcAvailable: hevcAvailable
        )
        cached = snapshot
        return snapshot
    }

    private func encoderAvailable(codec: CMVideoCodecType) -> Bool {
        var encoderList: CFArray?
        let status = VTCopyVideoEncoderList(nil, &encoderList)
        guard status == noErr, let encoders = encoderList as? [[CFString: Any]] else {
            return codec == kCMVideoCodecType_H264
        }
        return encoders.contains { item in
            (item[kVTVideoEncoderList_CodecType] as? NSNumber)?.uint32Value == codec
        }
    }
}
