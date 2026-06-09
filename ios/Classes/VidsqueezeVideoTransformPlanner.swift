import CoreGraphics

enum VidsqueezeVideoTransformPlanner {
    static func makeLayerTransform(
        preferredTransform: CGAffineTransform,
        naturalSize: CGSize,
        renderSize: CGSize
    ) -> CGAffineTransform {
        let sourceRect = CGRect(origin: .zero, size: naturalSize)
        let orientedRect = sourceRect.applying(preferredTransform)
        let orientedSize = CGSize(
            width: max(abs(orientedRect.width), 1),
            height: max(abs(orientedRect.height), 1)
        )
        let scale = min(renderSize.width / orientedSize.width, renderSize.height / orientedSize.height)
        let scaledSize = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        let offset = CGPoint(
            x: (renderSize.width - scaledSize.width) / 2,
            y: (renderSize.height - scaledSize.height) / 2
        )

        return CGAffineTransform(
            a: preferredTransform.a * scale,
            b: preferredTransform.b * scale,
            c: preferredTransform.c * scale,
            d: preferredTransform.d * scale,
            tx: (preferredTransform.tx - orientedRect.minX) * scale + offset.x,
            ty: (preferredTransform.ty - orientedRect.minY) * scale + offset.y
        )
    }
}
