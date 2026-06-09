package dev.wat.vidsqueeze.core

import android.net.Uri
import java.io.File

data class CompressionRequest(
    val inputUri: Uri,
    val outputDirectory: File,
    val outputFileName: String = "compressed_${System.currentTimeMillis()}.mp4",
    val preset: CompressionPreset = CompressionPreset.BALANCED,
    val maxResolutionCap: Int? = 1080,
    val allowHevc: Boolean = true,
    val keepAudio: Boolean = true,
    val keepOriginalIfLarger: Boolean = true,
    val forceCodec: ForceCodec = ForceCodec.AUTO,
    val maxBitrate: Int? = null,
    val progressIntervalMs: Long = 250L,
) {
    init {
        require(outputFileName.endsWith(".mp4")) { "Output file name must end with .mp4" }
        require(maxBitrate == null || maxBitrate > 0) { "maxBitrate must be > 0 when provided" }
        require(progressIntervalMs > 0) { "progressIntervalMs must be > 0" }
    }

    class Builder(
        private val inputUri: Uri,
        private val outputDirectory: File,
    ) {
        var outputFileName: String = "compressed_${System.currentTimeMillis()}.mp4"
        var preset: CompressionPreset = CompressionPreset.BALANCED
        var maxResolutionCap: Int? = 1080
        var allowHevc: Boolean = true
        var keepAudio: Boolean = true
        var keepOriginalIfLarger: Boolean = true
        var forceCodec: ForceCodec = ForceCodec.AUTO
        var maxBitrate: Int? = null
        var progressIntervalMs: Long = 250L

        fun build(): CompressionRequest {
            return CompressionRequest(
                inputUri = inputUri,
                outputDirectory = outputDirectory,
                outputFileName = outputFileName,
                preset = preset,
                maxResolutionCap = maxResolutionCap,
                allowHevc = allowHevc,
                keepAudio = keepAudio,
                keepOriginalIfLarger = keepOriginalIfLarger,
                forceCodec = forceCodec,
                maxBitrate = maxBitrate,
                progressIntervalMs = progressIntervalMs,
            )
        }
    }

    companion object {
        @JvmStatic
        fun builder(inputUri: Uri, outputDirectory: File): Builder {
            return Builder(inputUri, outputDirectory)
        }
    }
}

enum class ForceCodec {
    AUTO,
    AVC,
    HEVC,
}

fun buildCompressionRequest(
    inputUri: Uri,
    outputDirectory: File,
    block: CompressionRequest.Builder.() -> Unit = {},
): CompressionRequest {
    return CompressionRequest.Builder(
        inputUri = inputUri,
        outputDirectory = outputDirectory,
    ).apply(block).build()
}
