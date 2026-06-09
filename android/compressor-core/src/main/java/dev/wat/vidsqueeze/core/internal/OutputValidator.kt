package dev.wat.vidsqueeze.core.internal

import android.media.MediaMetadataRetriever
import java.io.File
import kotlin.math.abs

internal class OutputValidator {

    fun validate(file: File, source: SourceVideoInfo) {
        require(file.exists()) { "Output file missing" }
        require(file.length() > 0) { "Output file is empty" }

        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.absolutePath)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0

            require(width > 0 && height > 0) { "Output video track is unreadable" }
            require(abs(duration - source.durationMs) <= 1_500L) {
                "Output duration drift too large"
            }
        } finally {
            retriever.release()
        }
    }
}
