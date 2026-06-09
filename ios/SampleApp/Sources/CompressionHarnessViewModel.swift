import Combine
import Foundation
import PhotosUI

protocol FileImporting: Sendable {
    func importVideo(from url: URL) throws -> URL
}

extension FileImportService: FileImporting {}

protocol PhotoImporting: Sendable {
    func importVideo(from result: PHPickerResult, completion: @escaping (Result<URL, Error>) -> Void)
}

extension PhotoImportService: PhotoImporting {}

protocol CompressionStarting {
    func start(request: VidsqueezeCompressionRequest, listener: VidsqueezeCompressionListener) -> VidsqueezeCompressionHandle
}

extension VidsqueezeVideoCompressor: CompressionStarting {}

protocol SourceInspecting: Sendable {
    func inspect(url: URL) throws -> VidsqueezeSourceVideoInfo
}

extension VidsqueezeSourceInspector: SourceInspecting {}

@MainActor
final class CompressionHarnessViewModel: ObservableObject {
    @Published var selectedPreset: CompressionPresetOption = .balanced
    @Published var selectedResolutionCap: ResolutionCapOption = .p1080
    @Published var selectedCodec: ForceCodecOption = .auto
    @Published var allowHevc = true
    @Published var keepAudio = true
    @Published var keepOriginalIfLarger = true
    @Published var progressIntervalMsText = "250"
    @Published var maxBitrateText = ""
    @Published var sourceSummary: CompressionMediaSummary?
    @Published var outputSummary: CompressionResultSummary?
    @Published var benchmarkSummary: CompressionBenchmarkSummary?
    @Published var phaseLabel = "Idle"
    @Published var progressPercent = 0
    @Published var isCompressing = false
    @Published var isLoadingSource = false
    @Published var sourceLoadingMessage = ""
    @Published var errorMessage: String?
    @Published var logLines: [String] = []
    @Published var selectedSourceLabel = "No source selected"
    @Published var originalPreviewURL: URL?
    @Published var compressedPreviewURL: URL?

    private let compressor: CompressionStarting
    private let inspector: SourceInspecting
    private let fileImportService: FileImporting
    private let photoImportService: PhotoImporting
    private let fileManager: FileManager
    private var sourceURL: URL?
    private var sessionAdapter: CompressionSessionAdapting?

    init(
        compressor: CompressionStarting = VidsqueezeVideoCompressor(),
        inspector: SourceInspecting = VidsqueezeSourceInspector(),
        fileImportService: FileImporting = FileImportService(),
        photoImportService: PhotoImporting = PhotoImportService(),
        fileManager: FileManager = .default
    ) {
        self.compressor = compressor
        self.inspector = inspector
        self.fileImportService = fileImportService
        self.photoImportService = photoImportService
        self.fileManager = fileManager
    }

    func importFromDocument(url: URL) {
        beginSourceLoading(message: "Importing from Files...")
        Task {
            do {
                let localURL = try await importDocument(url: url)
                updateSourceLoadingMessage("Reading video info...")
                try await loadSource(from: localURL, origin: "Files")
            } catch {
                present(error: error)
            }
        }
    }

    func importFromPhoto(result: PHPickerResult?) {
        guard let result else { return }
        beginSourceLoading(message: "Importing from Photos...")
        photoImportService.importVideo(from: result) { [weak self] outcome in
            Task {
                guard let self else { return }
                do {
                    let localURL = try outcome.get()
                    self.updateSourceLoadingMessage("Reading video info...")
                    try await self.loadSource(from: localURL, origin: "Photos")
                } catch {
                    self.present(error: error)
                }
            }
        }
    }

    func compress() {
        guard !isCompressing else { return }
        guard let sourceURL else {
            errorMessage = "Pick a source video first."
            return
        }

        do {
            let outputURL = try makeOutputURL(for: sourceURL)
            let request = try makeRequest(inputURL: sourceURL, outputURL: outputURL)
            isCompressing = true
            progressPercent = 0
            phaseLabel = "Preparing"
            errorMessage = nil
            outputSummary = nil
            benchmarkSummary = nil
            compressedPreviewURL = nil
            appendLog("Compression started: \(request.outputURL.lastPathComponent)")

            let adapter = CompressionSessionAdapter(
                onState: { [weak self] state in
                    Task { @MainActor in
                        self?.apply(state: state)
                    }
                },
                onSuccess: { [weak self] result, elapsedMs in
                    Task { @MainActor in
                        self?.handleSuccess(result: result, elapsedMs: elapsedMs)
                    }
                },
                onFailure: { [weak self] failure, elapsedMs in
                    Task { @MainActor in
                        self?.handleFailure(failure: failure, elapsedMs: elapsedMs)
                    }
                }
            )
            let handle = compressor.start(request: request, listener: adapter)
            adapter.bind(handle: handle)
            sessionAdapter = adapter
        } catch {
            present(error: error)
        }
    }

    func cancelCompression() {
        sessionAdapter?.cancel()
        appendLog("Cancellation requested")
    }

    func makeRequest(inputURL: URL, outputURL: URL) throws -> VidsqueezeCompressionRequest {
        try VidsqueezeCompressionRequest(
            inputURL: inputURL,
            outputURL: outputURL,
            preset: selectedPreset.nativeValue,
            maxResolutionCap: selectedResolutionCap.nativeValue,
            allowHevc: allowHevc,
            keepAudio: keepAudio,
            keepOriginalIfLarger: keepOriginalIfLarger,
            forceCodec: selectedCodec.nativeValue,
            maxBitrate: parsedMaxBitrate,
            progressIntervalMs: parsedProgressIntervalMs
        )
    }

    private var parsedMaxBitrate: Int? {
        let trimmed = maxBitrateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private var parsedProgressIntervalMs: Int {
        Int(progressIntervalMsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 250
    }

    private func loadSource(from url: URL, origin: String) async throws {
        let info = try await inspectSource(url: url)
        sourceURL = url
        originalPreviewURL = url
        compressedPreviewURL = nil
        sourceSummary = CompressionMediaSummary(
            fileName: url.lastPathComponent,
            width: info.width,
            height: info.height,
            durationMs: info.durationMs,
            sizeBytes: info.fileSizeBytes,
            codecLabel: MediaInspectorFormatter.codecLabel(for: info),
            hasAudio: info.hasAudio
        )
        outputSummary = nil
        benchmarkSummary = nil
        errorMessage = nil
        phaseLabel = "Ready"
        progressPercent = 0
        selectedSourceLabel = "\(origin): \(url.lastPathComponent)"
        isLoadingSource = false
        sourceLoadingMessage = ""
        appendLog("Imported from \(origin): \(url.lastPathComponent)")
    }

    private func apply(state: VidsqueezeCompressionState) {
        switch state {
        case .preparing:
            phaseLabel = "Preparing"
        case .transcoding(let progress):
            phaseLabel = "Transcoding"
            progressPercent = progress
        case .finalizing:
            phaseLabel = "Finalizing"
            progressPercent = max(progressPercent, 99)
        case .completed:
            phaseLabel = "Completed"
            progressPercent = 100
        case .failed(_, let message):
            phaseLabel = "Failed"
            errorMessage = message
            isCompressing = false
        case .cancelled:
            phaseLabel = "Cancelled"
            isCompressing = false
        }
        appendLog("State: \(phaseLabel)\(state.progressSuffix)")
    }

    private func handleSuccess(result: VidsqueezeCompressionSuccess, elapsedMs: Int) {
        defer {
            isCompressing = false
            sessionAdapter = nil
        }

        do {
            let inspected = try inspector.inspect(url: result.outputURL)
            outputSummary = CompressionResultSummary(
                fileName: result.outputURL.lastPathComponent,
                outputURL: result.outputURL,
                width: inspected.width,
                height: inspected.height,
                durationMs: inspected.durationMs,
                sizeBytes: result.outputSizeBytes,
                codecLabel: MediaInspectorFormatter.codecLabel(for: result.codec),
                targetBitrate: result.targetBitrate,
                attempts: result.attempts,
                usedOriginalSource: result.usedOriginalSource
            )
            benchmarkSummary = CompressionBenchmarkSummary(
                elapsedMs: elapsedMs,
                sourceSizeBytes: result.sourceSizeBytes,
                outputSizeBytes: result.outputSizeBytes,
                attempts: result.attempts,
                usedOriginalSource: result.usedOriginalSource
            )
            compressedPreviewURL = result.outputURL
            phaseLabel = "Completed"
            progressPercent = 100
            appendLog("Compression completed in \(elapsedMs) ms")
        } catch {
            present(error: error)
        }
    }

    private func handleFailure(failure: VidsqueezeCompressionFailure, elapsedMs: Int) {
        isCompressing = false
        sessionAdapter = nil
        phaseLabel = failure.code == .cancelled ? "Cancelled" : "Failed"
        errorMessage = failure.message
        appendLog("Compression ended after \(elapsedMs) ms with \(failure.code.rawValue)")
    }

    private func makeOutputURL(for sourceURL: URL) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("vidsqueeze-sample", isDirectory: true)
            .appendingPathComponent("compressed", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = sourceURL.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(name)-\(Int(Date().timeIntervalSince1970)).mp4")
    }

    private func present(error: Error) {
        isCompressing = false
        isLoadingSource = false
        sourceLoadingMessage = ""
        sessionAdapter = nil
        errorMessage = error.localizedDescription
        appendLog("Error: \(error.localizedDescription)")
    }

    private func beginSourceLoading(message: String) {
        isLoadingSource = true
        sourceLoadingMessage = message
        errorMessage = nil
        phaseLabel = "Loading Source"
        progressPercent = 0
        appendLog(message)
    }

    private func updateSourceLoadingMessage(_ message: String) {
        sourceLoadingMessage = message
        appendLog(message)
    }

    private func importDocument(url: URL) async throws -> URL {
        let service = fileImportService
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let localURL = try service.importVideo(from: url)
                    continuation.resume(returning: localURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func inspectSource(url: URL) async throws -> VidsqueezeSourceVideoInfo {
        let inspector = inspector
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let info = try inspector.inspect(url: url)
                    continuation.resume(returning: info)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func appendLog(_ line: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withTime, .withFractionalSeconds]
        logLines.insert("[\(formatter.string(from: Date()))] \(line)", at: 0)
    }
}

private extension VidsqueezeCompressionState {
    var progressSuffix: String {
        if case .transcoding(let progressPercent) = self {
            return " \(progressPercent)%"
        }
        return ""
    }
}
