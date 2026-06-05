import AVFoundation
import Foundation

final class VidsqueezeErrorClassifier {
    func classify(_ error: Error) -> VidsqueezeCompressionFailure {
        if let failure = error as? VidsqueezeCompressionFailure {
            return failure
        }

        let nsError = error as NSError
        let code: VidsqueezeCompressionErrorCode
        switch nsError.domain {
        case NSCocoaErrorDomain:
            code = .ioFailed
        case AVFoundationErrorDomain:
            code = .transformFailed
        default:
            if nsError.code == NSUserCancelledError {
                code = .cancelled
            } else if error is CancellationError {
                code = .cancelled
            } else {
                code = .transformFailed
            }
        }

        return VidsqueezeCompressionFailure(
            code: code,
            message: nsError.localizedDescription,
            cause: error
        )
    }
}
