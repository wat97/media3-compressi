import Foundation

final class VidsqueezeFallbackPlanner {
    private let policyEngine = VidsqueezeCompressionPolicyEngine()

    func buildAttemptPlans(
        request: VidsqueezeCompressionRequest,
        source: VidsqueezeSourceVideoInfo,
        capability: VidsqueezeCapabilitySnapshot
    ) throws -> [VidsqueezeCompressionPlan] {
        let first = try policyEngine.plan(request: request, source: source, capability: capability)
        if request.forceCodec != .auto {
            return [first]
        }

        switch first.codec {
        case .hevc:
            if capability.avcAvailable {
                let retry = try policyEngine.plan(
                    request: request,
                    source: source,
                    capability: capability,
                    forcedCodec: .avc
                )
                return [first, retry]
            }
            return [first]
        case .avc:
            return [first]
        }
    }
}

