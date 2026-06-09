package dev.wat.vidsqueeze.core.internal

import dev.wat.vidsqueeze.core.CompressionRequest
import dev.wat.vidsqueeze.core.ForceCodec
import dev.wat.vidsqueeze.core.OutputCodec

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
