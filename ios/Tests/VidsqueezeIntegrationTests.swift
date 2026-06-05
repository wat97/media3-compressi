import AVFoundation
import CoreVideo
import Foundation
import XCTest
@testable import vidsqueeze

final class VidsqueezeIntegrationTests: XCTestCase {
    func testSourceInspectorReadsLocalMp4() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sourceURL = tempDirectory.appendingPathComponent("source.mp4")
        _ = try chooseCodecAndMakeFixture(
            sourceURL: sourceURL,
            size: CGSize(width: 320, height: 240),
            frameCount: 24,
            fps: 24
        )

        let info = try VidsqueezeSourceInspector().inspect(url: sourceURL)

        XCTAssertEqual(info.width, 320)
        XCTAssertEqual(info.height, 240)
        XCTAssertFalse(info.hasAudio)
        XCTAssertGreaterThan(info.durationMs, 900)
        XCTAssertGreaterThan(info.fileSizeBytes, 0)
    }

    func testVideoCompressorProducesCompressedMp4() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sourceURL = tempDirectory.appendingPathComponent("source.mp4")
        let outputURL = tempDirectory.appendingPathComponent("compressed.mp4")
        let codec = try chooseCodecAndMakeFixture(
            sourceURL: sourceURL,
            size: CGSize(width: 640, height: 360),
            frameCount: 30,
            fps: 30
        )

        let forceCodec: VidsqueezeForceCodec = codec == .h264 ? .avc : .hevc

        let request = try VidsqueezeCompressionRequest(
            inputURL: sourceURL,
            outputURL: outputURL,
            maxResolutionCap: 240,
            allowHevc: forceCodec == .hevc,
            keepAudio: false,
            keepOriginalIfLarger: false,
            forceCodec: forceCodec,
            maxBitrate: 1_400_000,
            progressIntervalMs: 10
        )

        let expectation = expectation(description: "compression completes")
        let listener = TestCompressionListener(expectation: expectation)
        let compressor = VidsqueezeVideoCompressor()
        _ = compressor.start(request: request, listener: listener)

        wait(for: [expectation], timeout: 30)

        let result = try XCTUnwrap(listener.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertEqual(result.codec, forceCodec == .hevc ? .hevc : .avc)
        XCTAssertEqual(result.targetHeight, 240)
        XCTAssertEqual(result.attempts, 1)
        XCTAssertFalse(result.usedOriginalSource)
        XCTAssertGreaterThan(result.outputSizeBytes, 0)
        XCTAssertTrue(listener.states.contains(.preparing))
        XCTAssertTrue(listener.states.contains(.finalizing))
        XCTAssertTrue(listener.states.contains(.completed))
    }

    private func makeTempDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func chooseCodecAndMakeFixture(
        sourceURL: URL,
        size: CGSize,
        frameCount: Int,
        fps: Int32
    ) throws -> AVVideoCodecType {
        for codec in [AVVideoCodecType.h264, AVVideoCodecType.hevc] {
            do {
                try TestAssetFactory.makeMp4(at: sourceURL, size: size, frameCount: frameCount, fps: fps, codec: codec)
                return codec
            } catch {
                try? FileManager.default.removeItem(at: sourceURL)
                let nsError = error as NSError
                if nsError.domain == AVFoundationErrorDomain, nsError.code == -11834 {
                    continue
                }
                throw error
            }
        }
        throw XCTSkip("Host encoder unavailable for integration fixture generation")
    }

}

private final class TestCompressionListener: VidsqueezeCompressionListener, @unchecked Sendable {
    let expectation: XCTestExpectation
    private(set) var states: [VidsqueezeCompressionState] = []
    private(set) var success: VidsqueezeCompressionSuccess?
    private(set) var failure: VidsqueezeCompressionFailure?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onStateChanged(_ state: VidsqueezeCompressionState) {
        states.append(state)
    }

    func onSuccess(_ result: VidsqueezeCompressionSuccess) {
        success = result
        expectation.fulfill()
    }

    func onFailure(_ failure: VidsqueezeCompressionFailure) {
        self.failure = failure
        expectation.fulfill()
    }
}

private enum TestAssetFactory {
    static func makeMp4(at url: URL, size: CGSize, frameCount: Int, fps: Int32, codec: AVVideoCodecType) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )

        guard writer.canAdd(input) else {
            throw NSError(domain: "test.asset", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input"])
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "test.asset", code: 2, userInfo: [NSLocalizedDescriptionKey: "Writer failed to start"])
        }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.001)
            }

            let presentationTime = CMTime(value: CMTimeValue(frame), timescale: fps)
            let color = UInt8((frame * 7) % 255)
            guard let pixelBuffer = makePixelBuffer(size: size, color: color) else {
                throw NSError(domain: "test.asset", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed creating pixel buffer"])
            }
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? NSError(domain: "test.asset", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed appending video frame"])
            }
        }
        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        if writer.status != .completed {
            throw writer.error ?? NSError(domain: "test.asset", code: 3, userInfo: [NSLocalizedDescriptionKey: "Writer failed to finalize"])
        }
    }

    private static func makePixelBuffer(size: CGSize, color: UInt8) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let pointer = baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
            for row in 0..<height {
                let offset = row * bytesPerRow
                for column in stride(from: 0, to: bytesPerRow, by: 4) {
                    pointer[offset + column] = color
                    pointer[offset + column + 1] = color
                    pointer[offset + column + 2] = color
                    pointer[offset + column + 3] = 255
                }
            }
        }

        return pixelBuffer
    }
}
