package dev.wat.vidsqueeze.core

import java.io.File

data class CompressionSuccess(
    val outputFile: File,
    val outputSizeBytes: Long,
    val sourceSizeBytes: Long,
    val durationMs: Long,
    val codec: OutputCodec,
    val targetHeight: Int?,
    val targetBitrate: Int,
    val attempts: Int,
    val usedOriginalSource: Boolean = false,
)

data class CompressionFailure(
    val code: CompressionErrorCode,
    val message: String,
    val cause: Throwable? = null,
)

enum class CompressionErrorCode {
    UNSUPPORTED_INPUT,
    CODEC_UNAVAILABLE,
    TRANSFORM_FAILED,
    IO_FAILED,
    VALIDATION_FAILED,
    CANCELLED,
}

enum class OutputCodec {
    AVC,
    HEVC,
}
