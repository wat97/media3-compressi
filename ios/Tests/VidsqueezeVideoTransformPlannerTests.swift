import CoreGraphics
import XCTest
@testable import vidsqueeze

final class VidsqueezeVideoTransformPlannerTests: XCTestCase {
    func testPortraitTransformIsNormalizedIntoRenderBounds() {
        let naturalSize = CGSize(width: 1920, height: 1080)
        let preferredTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        let renderSize = CGSize(width: 720, height: 1280)

        let transform = VidsqueezeVideoTransformPlanner.makeLayerTransform(
            preferredTransform: preferredTransform,
            naturalSize: naturalSize,
            renderSize: renderSize
        )

        let transformed = CGRect(origin: .zero, size: naturalSize).applying(transform)
        XCTAssertEqual(transformed.minX, 0, accuracy: 0.01)
        XCTAssertEqual(transformed.minY, 0, accuracy: 0.01)
        XCTAssertLessThanOrEqual(transformed.maxX, renderSize.width + 0.01)
        XCTAssertLessThanOrEqual(transformed.maxY, renderSize.height + 0.01)
    }

    func testLandscapeTransformScalesIntoRenderBounds() {
        let naturalSize = CGSize(width: 1920, height: 1080)
        let renderSize = CGSize(width: 1280, height: 720)

        let transform = VidsqueezeVideoTransformPlanner.makeLayerTransform(
            preferredTransform: .identity,
            naturalSize: naturalSize,
            renderSize: renderSize
        )

        let transformed = CGRect(origin: .zero, size: naturalSize).applying(transform)
        XCTAssertEqual(transformed.minX, 0, accuracy: 0.01)
        XCTAssertEqual(transformed.minY, 0, accuracy: 0.01)
        XCTAssertEqual(transformed.width, renderSize.width, accuracy: 0.01)
        XCTAssertEqual(transformed.height, renderSize.height, accuracy: 0.01)
    }
}
