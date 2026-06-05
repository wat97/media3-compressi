import Foundation
import XCTest
@testable import vidsqueeze

final class VidsqueezePolicyEngineTests: XCTestCase {
    private let capability = VidsqueezeCapabilitySnapshot(
        prefersHevc: true,
        avcAvailable: true,
        hevcAvailable: true
    )

    func testChooseCodecPrefersHevcWhenAllowed() throws {
        let engine = VidsqueezeCompressionPolicyEngine()

        let codec = try engine.chooseCodec(
            source: .fixture(),
            capability: capability,
            request: try .fixture()
        )

        XCTAssertEqual(codec, .hevc)
    }

    func testHdrSourceFallsBackToAvcCompatibilityPath() throws {
        let engine = VidsqueezeCompressionPolicyEngine()

        let codec = try engine.chooseCodec(
            source: .fixture(isHdr: true, isTenBit: true, isDolbyVision: true),
            capability: capability,
            request: try .fixture()
        )

        XCTAssertEqual(codec, .avc)
    }

    func testPresetBitrateOrderQualityBalancedSmallSize() {
        let engine = VidsqueezeCompressionPolicyEngine()
        let source = VidsqueezeSourceVideoInfo.fixture(bitrate: 8_000_000)

        let quality = engine.chooseTargetBitrate(source: source, codec: .avc, preset: .quality, targetHeight: nil, maxBitrate: nil)
        let balanced = engine.chooseTargetBitrate(source: source, codec: .avc, preset: .balanced, targetHeight: nil, maxBitrate: nil)
        let small = engine.chooseTargetBitrate(source: source, codec: .avc, preset: .smallSize, targetHeight: nil, maxBitrate: nil)

        XCTAssertGreaterThan(quality, balanced)
        XCTAssertGreaterThan(balanced, small)
    }

    func testPlanMapsKnobsIntoCompressionPlan() throws {
        let engine = VidsqueezeCompressionPolicyEngine()
        let plan = try engine.plan(
            request: try .fixture(
                preset: .smallSize,
                maxResolutionCap: 720,
                keepAudio: false,
                maxBitrate: 1_500_000,
                progressIntervalMs: 900
            ),
            source: .fixture(height: 1080),
            capability: capability
        )

        XCTAssertEqual(plan.codec, .hevc)
        XCTAssertEqual(plan.targetHeight, 720)
        XCTAssertEqual(plan.targetBitrate, 1_500_000)
        XCTAssertTrue(plan.removeAudio)
        XCTAssertFalse(plan.transcodeAudio)
        XCTAssertEqual(plan.progressIntervalMs, 900)
    }

    func testForcedCodecSkipsHevcWhenDisallowed() throws {
        let engine = VidsqueezeCompressionPolicyEngine()

        XCTAssertThrowsError(
            try engine.chooseCodec(
                source: .fixture(),
                capability: capability,
                request: try .fixture(allowHevc: false, forceCodec: .hevc)
            )
        )
    }
}

final class VidsqueezeFallbackPlannerTests: XCTestCase {
    func testFallbackPlannerAddsSingleAvcRetryForAutoHevcPlan() throws {
        let planner = VidsqueezeFallbackPlanner()
        let plans = try planner.buildAttemptPlans(
            request: try .fixture(),
            source: .fixture(),
            capability: .init(prefersHevc: true, avcAvailable: true, hevcAvailable: true)
        )

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans.first?.codec, .hevc)
        XCTAssertEqual(plans.last?.codec, .avc)
    }

    func testFallbackPlannerSkipsRetryForForcedCodec() throws {
        let planner = VidsqueezeFallbackPlanner()
        let plans = try planner.buildAttemptPlans(
            request: try .fixture(forceCodec: .avc),
            source: .fixture(),
            capability: .init(prefersHevc: true, avcAvailable: true, hevcAvailable: true)
        )

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.codec, .avc)
    }
}

final class VidsqueezeRequestAndValidationTests: XCTestCase {
    func testRequestRejectsNonMp4Output() {
        XCTAssertThrowsError(
            try VidsqueezeCompressionRequest(
                inputURL: URL(fileURLWithPath: "/tmp/in.mov"),
                outputURL: URL(fileURLWithPath: "/tmp/out.mov")
            )
        )
    }

    func testValidatorRejectsEmptyOutput() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let outputURL = tempDirectory.appendingPathComponent("empty.mp4")
        FileManager.default.createFile(atPath: outputURL.path, contents: Data())

        XCTAssertThrowsError(
            try VidsqueezeOutputValidator().validate(url: outputURL, source: .fixture())
        )
    }
}

private extension VidsqueezeCompressionRequest {
    static func fixture(
        preset: VidsqueezeCompressionPreset = .balanced,
        maxResolutionCap: Int? = 1080,
        allowHevc: Bool = true,
        keepAudio: Bool = true,
        keepOriginalIfLarger: Bool = true,
        forceCodec: VidsqueezeForceCodec = .auto,
        maxBitrate: Int? = nil,
        progressIntervalMs: Int = 250
    ) throws -> VidsqueezeCompressionRequest {
        try VidsqueezeCompressionRequest(
            inputURL: URL(fileURLWithPath: "/tmp/in.mp4"),
            outputURL: URL(fileURLWithPath: "/tmp/out.mp4"),
            preset: preset,
            maxResolutionCap: maxResolutionCap,
            allowHevc: allowHevc,
            keepAudio: keepAudio,
            keepOriginalIfLarger: keepOriginalIfLarger,
            forceCodec: forceCodec,
            maxBitrate: maxBitrate,
            progressIntervalMs: progressIntervalMs
        )
    }
}

private extension VidsqueezeSourceVideoInfo {
    static func fixture(
        width: Int = 1920,
        height: Int = 1080,
        frameRate: Double = 30,
        bitrate: Int? = 8_000_000,
        durationMs: Int = 10_000,
        fileSizeBytes: Int64 = 100_000_000,
        hasAudio: Bool = true,
        isHdr: Bool = false,
        isTenBit: Bool = false,
        isDolbyVision: Bool = false,
        codecSubType: FourCharCode? = nil
    ) -> VidsqueezeSourceVideoInfo {
        VidsqueezeSourceVideoInfo(
            url: URL(fileURLWithPath: "/tmp/in.mp4"),
            width: width,
            height: height,
            frameRate: frameRate,
            bitrate: bitrate,
            durationMs: durationMs,
            fileSizeBytes: fileSizeBytes,
            hasAudio: hasAudio,
            isHdr: isHdr,
            isTenBit: isTenBit,
            isDolbyVision: isDolbyVision,
            codecSubType: codecSubType
        )
    }
}
