package dev.wat.vidsqueeze.core.internal

import dev.wat.vidsqueeze.core.CompressionPreset
import dev.wat.vidsqueeze.core.CompressionRequest
import dev.wat.vidsqueeze.core.ForceCodec
import dev.wat.vidsqueeze.core.OutputCodec
import kotlin.math.roundToInt

internal class CompressionPolicyEngine {

    fun plan(
        request: CompressionRequest,
        source: SourceVideoInfo,
        capability: CapabilitySnapshot,
        forcedCodec: OutputCodec? = null,
    ): CompressionPlan {
        val codec = forcedCodec ?: chooseCodec(source, capability, request)
        val targetHeight = chooseTargetHeight(source, request.maxResolutionCap)
        val targetBitrate = chooseTargetBitrate(
            source = source,
            codec = codec,
            preset = request.preset,
            targetHeight = targetHeight,
            maxBitrate = request.maxBitrate,
        )
        val shouldKeepAudio = request.keepAudio && source.hasAudio

        return CompressionPlan(
            codec = codec,
            targetHeight = targetHeight,
            targetBitrate = targetBitrate,
            removeAudio = !shouldKeepAudio,
            transcodeAudio = shouldKeepAudio && shouldTranscodeAudio(source),
            audioBitrate = if (shouldKeepAudio && shouldTranscodeAudio(source)) 128_000 else null,
            outputDirectory = request.outputDirectory,
            outputFileName = request.outputFileName,
            preset = request.preset,
            progressIntervalMs = request.progressIntervalMs,
        )
    }

    internal fun chooseCodec(
        source: SourceVideoInfo,
        capability: CapabilitySnapshot,
        request: CompressionRequest,
    ): OutputCodec {
        when (request.forceCodec) {
            ForceCodec.AVC -> {
                check(capability.avcEncoderAvailable) { "Requested AVC encoder is unavailable" }
                return OutputCodec.AVC
            }
            ForceCodec.HEVC -> {
                check(capability.hevcEncoderAvailable) { "Requested HEVC encoder is unavailable" }
                check(request.allowHevc) { "HEVC requested while allowHevc is false" }
                return OutputCodec.HEVC
            }
            ForceCodec.AUTO -> Unit
        }

        if (!capability.avcEncoderAvailable && !capability.hevcEncoderAvailable) {
            throw IllegalStateException("No supported hardware video encoder found")
        }

        if (
            request.allowHevc &&
            capability.apiLevel >= 34 &&
            capability.hevcEncoderAvailable &&
            !source.isHdr &&
            !source.isTenBit
        ) {
            return OutputCodec.HEVC
        }

        if (capability.avcEncoderAvailable) {
            return OutputCodec.AVC
        }

        return OutputCodec.HEVC
    }

    internal fun chooseTargetHeight(
        source: SourceVideoInfo,
        maxResolutionCap: Int?,
    ): Int? {
        val cap = maxResolutionCap ?: return null
        return if (source.height > cap) cap.makeEven() else null
    }

    internal fun chooseTargetBitrate(
        source: SourceVideoInfo,
        codec: OutputCodec,
        preset: CompressionPreset,
        targetHeight: Int?,
        maxBitrate: Int?,
    ): Int {
        val inputBitrate = source.bitrate ?: fallbackInputBitrate(source)
        val scaleFactor = if (targetHeight == null || source.height == 0) {
            1.0
        } else {
            targetHeight.toDouble() / source.height.toDouble()
        }
        val codecFactor = when (codec) {
            OutputCodec.AVC -> preset.avcBitrateFactor
            OutputCodec.HEVC -> preset.hevcBitrateFactor
        }
        val fpsFactor = if ((source.frameRate ?: 30) > 30) 1.12 else 1.0
        val scaled = inputBitrate * scaleFactor * codecFactor * fpsFactor
        val computed = scaled.roundToInt().coerceAtLeast(1_200_000)
        return maxBitrate?.let { minOf(computed, it) } ?: computed
    }

    private fun shouldTranscodeAudio(source: SourceVideoInfo): Boolean {
        val mime = source.mimeType.orEmpty()
        return source.hasAudio && !mime.contains("mp4", ignoreCase = true)
    }

    private fun fallbackInputBitrate(source: SourceVideoInfo): Int {
        val pixels = source.width * source.height
        val fps = source.frameRate ?: 30
        return (pixels * fps * 0.12).roundToInt().coerceAtLeast(2_000_000)
    }

    private fun Int.makeEven(): Int = if (this % 2 == 0) this else this - 1
}
