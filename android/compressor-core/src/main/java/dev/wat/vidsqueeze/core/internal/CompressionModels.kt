package dev.wat.vidsqueeze.core.internal

import android.net.Uri
import dev.wat.vidsqueeze.core.CompressionPreset
import dev.wat.vidsqueeze.core.OutputCodec
import java.io.File

internal data class SourceVideoInfo(
    val uri: Uri,
    val mimeType: String?,
    val width: Int,
    val height: Int,
    val frameRate: Int?,
    val bitrate: Int?,
    val durationMs: Long,
    val rotationDegrees: Int,
    val fileSizeBytes: Long,
    val hasAudio: Boolean,
    val isHdr: Boolean,
    val isTenBit: Boolean,
) {
    val longestEdge: Int = maxOf(width, height)
    val shortestEdge: Int = minOf(width, height)
}

internal data class CapabilitySnapshot(
    val apiLevel: Int,
    val hevcEncoderAvailable: Boolean,
    val avcEncoderAvailable: Boolean,
)

internal data class CompressionPlan(
    val codec: OutputCodec,
    val targetHeight: Int?,
    val targetBitrate: Int,
    val removeAudio: Boolean,
    val transcodeAudio: Boolean,
    val audioBitrate: Int?,
    val outputDirectory: File,
    val outputFileName: String,
    val preset: CompressionPreset,
    val progressIntervalMs: Long,
)
