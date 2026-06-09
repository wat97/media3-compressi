import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

final class VidsqueezeVideoCompressor {
    private let sourceInspector: VidsqueezeSourceInspector
    private let capabilityResolver: VidsqueezeCapabilityResolver
    private let fallbackPlanner: VidsqueezeFallbackPlanner
    private let outputValidator: VidsqueezeOutputValidator
    private let errorClassifier: VidsqueezeErrorClassifier
    private let workQueue: DispatchQueue

    init(
        sourceInspector: VidsqueezeSourceInspector = VidsqueezeSourceInspector(),
        capabilityResolver: VidsqueezeCapabilityResolver = VidsqueezeCapabilityResolver(),
        fallbackPlanner: VidsqueezeFallbackPlanner = VidsqueezeFallbackPlanner(),
        outputValidator: VidsqueezeOutputValidator = VidsqueezeOutputValidator(),
        errorClassifier: VidsqueezeErrorClassifier = VidsqueezeErrorClassifier(),
        workQueue: DispatchQueue = DispatchQueue(label: "dev.wat.vidsqueeze.ios.compressor", qos: .userInitiated)
    ) {
        self.sourceInspector = sourceInspector
        self.capabilityResolver = capabilityResolver
        self.fallbackPlanner = fallbackPlanner
        self.outputValidator = outputValidator
        self.errorClassifier = errorClassifier
        self.workQueue = workQueue
    }

    func preparePlans(for request: VidsqueezeCompressionRequest, source: VidsqueezeSourceVideoInfo) throws -> [VidsqueezeCompressionPlan] {
        try fallbackPlanner.buildAttemptPlans(
            request: request,
            source: source,
            capability: capabilityResolver.resolve()
        )
    }

    @discardableResult
    func start(
        request: VidsqueezeCompressionRequest,
        listener: VidsqueezeCompressionListener
    ) -> VidsqueezeCompressionHandle {
        let task = VidsqueezeCompressionTask(
            request: request,
            listener: listener,
            sourceInspector: sourceInspector,
            capabilityResolver: capabilityResolver,
            fallbackPlanner: fallbackPlanner,
            outputValidator: outputValidator,
            errorClassifier: errorClassifier
        )
        workQueue.async {
            task.run()
        }
        return task
    }
}

private final class VidsqueezeCompressionTask: VidsqueezeCompressionHandle, @unchecked Sendable {
    private let request: VidsqueezeCompressionRequest
    private let listener: VidsqueezeCompressionListener
    private let sourceInspector: VidsqueezeSourceInspector
    private let capabilityResolver: VidsqueezeCapabilityResolver
    private let fallbackPlanner: VidsqueezeFallbackPlanner
    private let outputValidator: VidsqueezeOutputValidator
    private let errorClassifier: VidsqueezeErrorClassifier
    private let fileManager: FileManager
    private let stateLock = NSLock()
    private var cancelled = false
    private var currentReader: AVAssetReader?
    private var currentWriter: AVAssetWriter?
    private let progressReporter = VidsqueezeProgressReporter()

    init(
        request: VidsqueezeCompressionRequest,
        listener: VidsqueezeCompressionListener,
        sourceInspector: VidsqueezeSourceInspector,
        capabilityResolver: VidsqueezeCapabilityResolver,
        fallbackPlanner: VidsqueezeFallbackPlanner,
        outputValidator: VidsqueezeOutputValidator,
        errorClassifier: VidsqueezeErrorClassifier,
        fileManager: FileManager = .default
    ) {
        self.request = request
        self.listener = listener
        self.sourceInspector = sourceInspector
        self.capabilityResolver = capabilityResolver
        self.fallbackPlanner = fallbackPlanner
        self.outputValidator = outputValidator
        self.errorClassifier = errorClassifier
        self.fileManager = fileManager
    }

    func cancel() {
        stateLock.lock()
        cancelled = true
        let reader = currentReader
        let writer = currentWriter
        stateLock.unlock()

        reader?.cancelReading()
        writer?.cancelWriting()
    }

    func run() {
        dispatchState(.preparing)

        do {
            try ensureOutputDirectory()
            let source = try sourceInspector.inspect(url: request.inputURL)
            let capability = capabilityResolver.resolve()
            let plans = try fallbackPlanner.buildAttemptPlans(
                request: request,
                source: source,
                capability: capability
            )

            var lastError: Error?
            for (index, plan) in plans.enumerated() {
                try ensureNotCancelled()
                let tempURL = temporaryOutputURL()
                try? fileManager.removeItem(at: tempURL)

                do {
                    dispatchState(.transcoding(progressPercent: 0))
                    try executeAttempt(source: source, plan: plan, outputURL: tempURL)
                    dispatchState(.finalizing)
                    try outputValidator.validate(url: tempURL, source: source)
                    let finalURL = try finalizeOutput(tempURL: tempURL, source: source)
                    let outputSize = try Int64(fileSize(at: finalURL))
                    let success = VidsqueezeCompressionSuccess(
                        outputURL: finalURL,
                        outputSizeBytes: outputSize,
                        sourceSizeBytes: source.fileSizeBytes,
                        durationMs: source.durationMs,
                        codec: plan.codec,
                        targetHeight: plan.targetHeight,
                        targetBitrate: plan.targetBitrate,
                        attempts: index + 1,
                        usedOriginalSource: finalURL.standardizedFileURL == request.inputURL.standardizedFileURL
                    )
                    dispatchState(.completed)
                    dispatchSuccess(success)
                    return
                } catch {
                    try? fileManager.removeItem(at: tempURL)
                    try ensureNotCancelled()
                    lastError = error
                }
            }

            throw lastError ?? VidsqueezeCompressionFailure(
                code: .transformFailed,
                message: "Compression failed with no root cause"
            )
        } catch {
            let failure = currentFailure(from: error)
            if failure.code == .cancelled {
                dispatchState(.cancelled)
            } else {
                dispatchState(.failed(code: failure.code, message: failure.message))
            }
            dispatchFailure(failure)
        }
    }

    private func executeAttempt(
        source: VidsqueezeSourceVideoInfo,
        plan: VidsqueezeCompressionPlan,
        outputURL: URL
    ) throws {
        let asset = AVURLAsset(url: source.url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VidsqueezeCompressionFailure(code: .unsupportedInput, message: "Input has no readable video track")
        }

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        setCurrent(reader: reader, writer: writer)
        defer { clearCurrent() }

        let renderSize = makeRenderSize(for: source, targetHeight: plan.targetHeight)
        let videoComposition = makeVideoComposition(
            assetDuration: asset.duration,
            videoTrack: videoTrack,
            renderSize: renderSize,
            frameRate: source.frameRate
        )

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [videoTrack],
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            ]
        )
        videoOutput.videoComposition = videoComposition
        guard reader.canAdd(videoOutput) else {
            throw VidsqueezeCompressionFailure(code: .transformFailed, message: "Cannot add video reader output")
        }
        reader.add(videoOutput)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoWriterSettings(plan: plan, renderSize: renderSize, frameRate: source.frameRate)
        )
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else {
            throw VidsqueezeCompressionFailure(code: .codecUnavailable, message: "Cannot add video writer input")
        }
        writer.add(videoInput)

        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if !plan.removeAudio, let track = asset.tracks(withMediaType: .audio).first {
            let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: pcmAudioReaderSettings())
            trackOutput.alwaysCopiesSampleData = false
            guard reader.canAdd(trackOutput) else {
                throw VidsqueezeCompressionFailure(code: .transformFailed, message: "Cannot add audio reader output")
            }
            reader.add(trackOutput)

            let writerInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioWriterSettings(track: track, targetBitrate: plan.audioBitrate ?? 96_000)
            )
            writerInput.expectsMediaDataInRealTime = false
            guard writer.canAdd(writerInput) else {
                throw VidsqueezeCompressionFailure(code: .transformFailed, message: "Cannot add audio writer input")
            }
            writer.add(writerInput)
            audioOutput = trackOutput
            audioInput = writerInput
        }

        guard reader.startReading() else {
            throw reader.error ?? VidsqueezeCompressionFailure(code: .transformFailed, message: "Reader failed to start")
        }
        guard writer.startWriting() else {
            throw writer.error ?? VidsqueezeCompressionFailure(code: .transformFailed, message: "Writer failed to start")
        }
        writer.startSession(atSourceTime: .zero)

        let group = DispatchGroup()
        let pumpError = LockedBox<Error>()

        schedulePump(
            readerOutput: videoOutput,
            writerInput: videoInput,
            queue: DispatchQueue(label: "dev.wat.vidsqueeze.ios.video-pump"),
            group: group,
            sharedError: pumpError
        ) { [weak self] sampleBuffer in
            self?.progressReporter.report(
                sampleBuffer: sampleBuffer,
                durationMs: source.durationMs,
                intervalMs: plan.progressIntervalMs
            ) { progress in
                self?.dispatchState(.transcoding(progressPercent: progress))
            }
        }

        if let audioOutput, let audioInput {
            schedulePump(
                readerOutput: audioOutput,
                writerInput: audioInput,
                queue: DispatchQueue(label: "dev.wat.vidsqueeze.ios.audio-pump"),
                group: group,
                sharedError: pumpError,
                onSample: nil
            )
        }

        group.wait()
        try ensureNotCancelled()
        if let error = pumpError.value {
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }
        if reader.status == .failed {
            throw reader.error ?? VidsqueezeCompressionFailure(code: .transformFailed, message: "Reader failed")
        }
        if writer.status == .failed {
            throw writer.error ?? VidsqueezeCompressionFailure(code: .transformFailed, message: "Writer failed")
        }

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()
        try ensureNotCancelled()

        switch writer.status {
        case .completed:
            break
        case .failed:
            throw writer.error ?? VidsqueezeCompressionFailure(code: .transformFailed, message: "Writer failed during finalize")
        case .cancelled:
            throw CancellationError()
        default:
            throw VidsqueezeCompressionFailure(code: .transformFailed, message: "Writer completed with unexpected status")
        }
    }

    private func schedulePump(
        readerOutput: AVAssetReaderOutput,
        writerInput: AVAssetWriterInput,
        queue: DispatchQueue,
        group: DispatchGroup,
        sharedError: LockedBox<Error>,
        onSample: ((CMSampleBuffer) -> Void)?
    ) {
        let state = PumpState()
        group.enter()
        writerInput.requestMediaDataWhenReady(on: queue) { [weak self] in
            guard let self else {
                state.finish(group: group)
                return
            }

            while writerInput.isReadyForMoreMediaData {
                if self.isCancelled {
                    writerInput.markAsFinished()
                    state.finish(group: group)
                    return
                }
                if sharedError.value != nil {
                    writerInput.markAsFinished()
                    state.finish(group: group)
                    return
                }

                guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                    writerInput.markAsFinished()
                    state.finish(group: group)
                    return
                }

                if !writerInput.append(sampleBuffer) {
                    sharedError.set(
                        VidsqueezeCompressionFailure(code: .transformFailed, message: "Failed to append media sample")
                    )
                    writerInput.markAsFinished()
                    state.finish(group: group)
                    return
                }
                onSample?(sampleBuffer)
            }
        }
    }

    private func videoWriterSettings(plan: VidsqueezeCompressionPlan, renderSize: CGSize, frameRate: Double) -> [String: Any] {
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: plan.targetBitrate,
            AVVideoExpectedSourceFrameRateKey: max(Int(frameRate.rounded()), 1),
            AVVideoAllowFrameReorderingKey: false,
        ]
        switch plan.codec {
        case .avc:
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        case .hevc:
            compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel as String
        }

        return [
            AVVideoCodecKey: plan.codec.avFoundationCodec,
            AVVideoWidthKey: Int(renderSize.width.rounded()),
            AVVideoHeightKey: Int(renderSize.height.rounded()),
            AVVideoCompressionPropertiesKey: compressionProperties,
        ]
    }

    private func pcmAudioReaderSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
    }

    private func audioWriterSettings(track: AVAssetTrack, targetBitrate: Int) -> [String: Any] {
        let audioDescription = track.formatDescriptions.first.map { $0 as! CMAudioFormatDescription }
        let basicDescription = audioDescription.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
        let sampleRate = basicDescription?.mSampleRate ?? 44_100
        let channelCount = Int(basicDescription?.mChannelsPerFrame ?? 2)

        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: min(max(channelCount, 1), 2),
            AVEncoderBitRateKey: targetBitrate,
        ]
    }

    private func makeVideoComposition(
        assetDuration: CMTime,
        videoTrack: AVAssetTrack,
        renderSize: CGSize,
        frameRate: Double
    ) -> AVMutableVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        composition.frameDuration = CMTime(
            value: 1,
            timescale: Int32(max(Int(frameRate.rounded()), 1))
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(
            VidsqueezeVideoTransformPlanner.makeLayerTransform(
                preferredTransform: videoTrack.preferredTransform,
                naturalSize: videoTrack.naturalSize,
                renderSize: renderSize
            ),
            at: .zero
        )

        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        return composition
    }

    private func makeRenderSize(for source: VidsqueezeSourceVideoInfo, targetHeight: Int?) -> CGSize {
        let sourceWidth = max(source.width, 2)
        let sourceHeight = max(source.height, 2)
        guard let targetHeight, targetHeight < sourceHeight else {
            return CGSize(width: even(sourceWidth), height: even(sourceHeight))
        }

        let scale = Double(targetHeight) / Double(sourceHeight)
        let scaledWidth = max(Int((Double(sourceWidth) * scale).rounded()), 2)
        return CGSize(width: even(scaledWidth), height: even(targetHeight))
    }

    private func temporaryOutputURL() -> URL {
        request.outputURL
            .deletingPathExtension()
            .appendingPathExtension("tmp.mp4")
    }

    private func ensureOutputDirectory() throws {
        let directory = request.outputURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw VidsqueezeCompressionFailure(code: .ioFailed, message: "Output directory path is not a directory")
            }
            return
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func finalizeOutput(tempURL: URL, source: VidsqueezeSourceVideoInfo) throws -> URL {
        let useOriginal = shouldKeepOriginalSource(source: source, compressedURL: tempURL)
        if useOriginal {
            try? fileManager.removeItem(at: tempURL)
            return request.inputURL
        }

        try? fileManager.removeItem(at: request.outputURL)
        try fileManager.moveItem(at: tempURL, to: request.outputURL)
        return request.outputURL
    }

    private func shouldKeepOriginalSource(source: VidsqueezeSourceVideoInfo, compressedURL: URL) -> Bool {
        guard request.keepOriginalIfLarger, request.inputURL.isFileURL else {
            return false
        }
        let compressedSize = (try? fileSize(at: compressedURL)) ?? 0
        guard compressedSize > 0, source.fileSizeBytes > 0 else {
            return false
        }
        return Int64(compressedSize) >= source.fileSizeBytes
    }

    private func fileSize(at url: URL) throws -> Int {
        try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    }

    private func ensureNotCancelled() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    private var isCancelled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return cancelled
    }

    private func setCurrent(reader: AVAssetReader, writer: AVAssetWriter) {
        stateLock.lock()
        currentReader = reader
        currentWriter = writer
        stateLock.unlock()
    }

    private func clearCurrent() {
        stateLock.lock()
        currentReader = nil
        currentWriter = nil
        stateLock.unlock()
    }

    private func currentFailure(from error: Error) -> VidsqueezeCompressionFailure {
        if isCancelled || error is CancellationError {
            return VidsqueezeCompressionFailure(code: .cancelled, message: "Compression cancelled", cause: error)
        }
        return errorClassifier.classify(error)
    }

    private func dispatchState(_ state: VidsqueezeCompressionState) {
        DispatchQueue.main.async { [listener] in
            listener.onStateChanged(state)
        }
    }

    private func dispatchSuccess(_ result: VidsqueezeCompressionSuccess) {
        DispatchQueue.main.async { [listener] in
            listener.onSuccess(result)
        }
    }

    private func dispatchFailure(_ failure: VidsqueezeCompressionFailure) {
        DispatchQueue.main.async { [listener] in
            listener.onFailure(failure)
        }
    }

    private func even(_ value: Int) -> Int {
        value.isMultiple(of: 2) ? value : value - 1
    }
}

private final class PumpState: @unchecked Sendable {
    private var leftGroup = false
    private let lock = NSLock()

    func finish(group: DispatchGroup) {
        lock.lock()
        defer { lock.unlock() }
        guard !leftGroup else { return }
        leftGroup = true
        group.leave()
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value?

    var value: Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ value: Value) {
        lock.lock()
        if storage == nil {
            storage = value
        }
        lock.unlock()
    }
}

private final class VidsqueezeProgressReporter: @unchecked Sendable {
    private let lock = NSLock()
    private var lastEmitUptimeNs: UInt64 = 0
    private var lastProgress = -1

    func report(
        sampleBuffer: CMSampleBuffer,
        durationMs: Int,
        intervalMs: Int,
        emit: (Int) -> Void
    ) {
        guard durationMs > 0 else { return }
        let timeSeconds = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard timeSeconds.isFinite else { return }
        let progress = min(max(Int((timeSeconds * 1000.0 / Double(durationMs)) * 100.0), 0), 99)
        let now = DispatchTime.now().uptimeNanoseconds

        lock.lock()
        let intervalNs = UInt64(intervalMs) * 1_000_000
        let shouldEmit = progress > lastProgress && (lastEmitUptimeNs == 0 || now - lastEmitUptimeNs >= intervalNs)
        if shouldEmit {
            lastProgress = progress
            lastEmitUptimeNs = now
        }
        lock.unlock()

        if shouldEmit {
            emit(progress)
        }
    }
}
