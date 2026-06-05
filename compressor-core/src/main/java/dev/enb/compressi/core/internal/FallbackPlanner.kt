package dev.enb.compressi.core.internal

import dev.enb.compressi.core.CompressionRequest
import dev.enb.compressi.core.OutputCodec

internal class FallbackPlanner(
    private val policyEngine: CompressionPolicyEngine,
) {

    fun buildAttemptPlans(
        request: CompressionRequest,
        source: SourceVideoInfo,
        capability: CapabilitySnapshot,
    ): List<CompressionPlan> {
        val firstPlan = policyEngine.plan(request, source, capability)
        val retryPlan = when (firstPlan.codec) {
            OutputCodec.HEVC -> policyEngine.plan(request, source, capability, forcedCodec = OutputCodec.AVC)
            OutputCodec.AVC -> if (capability.apiLevel < 29) {
                firstPlan.copy(
                    targetHeight = minOf(firstPlan.targetHeight ?: source.height, 720),
                    targetBitrate = (firstPlan.targetBitrate * 0.84).toInt(),
                )
            } else {
                null
            }
        }
        return listOfNotNull(firstPlan, retryPlan)
    }
}

