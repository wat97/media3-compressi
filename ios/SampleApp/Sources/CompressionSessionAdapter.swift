import Foundation

protocol CompressionSessionAdapting: AnyObject {
    var elapsedMs: Int { get }
    func bind(handle: VidsqueezeCompressionHandle)
    func cancel()
}

final class CompressionSessionAdapter: CompressionSessionAdapting, VidsqueezeCompressionListener, @unchecked Sendable {
    private let onState: @Sendable (VidsqueezeCompressionState) -> Void
    private let onSuccess: @Sendable (VidsqueezeCompressionSuccess, Int) -> Void
    private let onFailure: @Sendable (VidsqueezeCompressionFailure, Int) -> Void
    private let dateProvider: () -> Date
    private var handle: VidsqueezeCompressionHandle?
    private var startedAt: Date?
    private var endedAt: Date?

    init(
        onState: @escaping @Sendable (VidsqueezeCompressionState) -> Void,
        onSuccess: @escaping @Sendable (VidsqueezeCompressionSuccess, Int) -> Void,
        onFailure: @escaping @Sendable (VidsqueezeCompressionFailure, Int) -> Void,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.onState = onState
        self.onSuccess = onSuccess
        self.onFailure = onFailure
        self.dateProvider = dateProvider
    }

    var elapsedMs: Int {
        let start = startedAt ?? dateProvider()
        let end = endedAt ?? dateProvider()
        return max(Int(end.timeIntervalSince(start) * 1000), 0)
    }

    func bind(handle: VidsqueezeCompressionHandle) {
        self.handle = handle
        startedAt = dateProvider()
        endedAt = nil
    }

    func cancel() {
        handle?.cancel()
    }

    func onStateChanged(_ state: VidsqueezeCompressionState) {
        if case .cancelled = state {
            endedAt = dateProvider()
        }
        DispatchQueue.main.async {
            self.onState(state)
        }
    }

    func onSuccess(_ result: VidsqueezeCompressionSuccess) {
        endedAt = dateProvider()
        let elapsed = elapsedMs
        DispatchQueue.main.async {
            self.onSuccess(result, elapsed)
        }
    }

    func onFailure(_ failure: VidsqueezeCompressionFailure) {
        endedAt = dateProvider()
        let elapsed = elapsedMs
        DispatchQueue.main.async {
            self.onFailure(failure, elapsed)
        }
    }
}
