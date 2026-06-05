package dev.enb.compressi.core.internal

import dev.enb.compressi.core.CompressionRequest
import dev.enb.compressi.core.ForceCodec
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
        if (request.forceCodec != ForceCodec.AUTO) {
            return listOf(firstPlan)
        }

        val retryPlan = when (firstPlan.codec) {
            OutputCodec.HEVC -> if (capability.avcEncoderAvailable) {
                policyEngine.plan(request, source, capability, forcedCodec = OutputCodec.AVC)
            } else {
                null
            }
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
