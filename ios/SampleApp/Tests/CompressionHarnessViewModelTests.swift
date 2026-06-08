import Foundation
import XCTest
@testable import vidsqueeze_sample

final class CompressionHarnessViewModelTests: XCTestCase {
    func testMegabytesFormattingUsesFamiliarUnit() {
        XCTAssertEqual(MediaInspectorFormatter.megabytes(5_242_880), "5.00 MB")
    }

    func testSavedPercentUsesSourceAndOutputSizes() {
        XCTAssertEqual(
            MediaInspectorFormatter.savedPercent(sourceBytes: 100_000_000, outputBytes: 25_000_000),
            "75.0%"
        )
    }

    @MainActor
    func testRequestBuilderMapsUiOptionsIntoNativeRequest() throws {
        let viewModel = CompressionHarnessViewModel(
            compressor: TestCompressor(),
            inspector: TestInspector()
        )
        viewModel.selectedPreset = .smallSize
        viewModel.selectedResolutionCap = .p720
        viewModel.selectedCodec = .avc
        viewModel.allowHevc = false
        viewModel.keepAudio = false
        viewModel.keepOriginalIfLarger = false
        viewModel.maxBitrateText = "1500000"
        viewModel.progressIntervalMsText = "900"

        let request = try viewModel.makeRequest(
            inputURL: URL(fileURLWithPath: "/tmp/input.mp4"),
            outputURL: URL(fileURLWithPath: "/tmp/output.mp4")
        )

        XCTAssertEqual(request.preset, .smallSize)
        XCTAssertEqual(request.maxResolutionCap, 720)
        XCTAssertEqual(request.forceCodec, .avc)
        XCTAssertFalse(request.allowHevc)
        XCTAssertFalse(request.keepAudio)
        XCTAssertFalse(request.keepOriginalIfLarger)
        XCTAssertEqual(request.maxBitrate, 1_500_000)
        XCTAssertEqual(request.progressIntervalMs, 900)
    }
}

private struct TestInspector: SourceInspecting {
    func inspect(url: URL) throws -> VidsqueezeSourceVideoInfo {
        VidsqueezeSourceVideoInfo(
            url: url,
            width: 1920,
            height: 1080,
            frameRate: 30,
            bitrate: 8_000_000,
            durationMs: 10_000,
            fileSizeBytes: 100_000_000,
            hasAudio: true,
            isHdr: false,
            isTenBit: false,
            isDolbyVision: false,
            codecSubType: nil
        )
    }
}

private final class TestCompressor: CompressionStarting {
    func start(request: VidsqueezeCompressionRequest, listener: VidsqueezeCompressionListener) -> VidsqueezeCompressionHandle {
        TestHandle()
    }
}

private final class TestHandle: VidsqueezeCompressionHandle, @unchecked Sendable {
    func cancel() {}
}
