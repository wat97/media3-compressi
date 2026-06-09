package dev.wat.vidsqueeze.core.internal

import android.content.ContentResolver
import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.core.net.toFile

internal class SourceInspector(
    private val context: Context,
) {
    fun inspect(inputUri: Uri): SourceVideoInfo {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, inputUri)
            SourceVideoInfo(
                uri = inputUri,
                mimeType = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE),
                width = retriever.extractInt(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH),
                height = retriever.extractInt(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT),
                frameRate = retriever.extractIntOrNull(MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE),
                bitrate = retriever.extractIntOrNull(MediaMetadataRetriever.METADATA_KEY_BITRATE),
                durationMs = retriever.extractLong(MediaMetadataRetriever.METADATA_KEY_DURATION),
                rotationDegrees = retriever.extractInt(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION),
                fileSizeBytes = queryFileSize(inputUri),
                hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes",
                isHdr = isHdr(retriever),
                isTenBit = isTenBit(retriever),
            )
        } finally {
            retriever.release()
        }
    }

    private fun queryFileSize(uri: Uri): Long {
        if (ContentResolver.SCHEME_FILE == uri.scheme) {
            return runCatching { uri.toFile().length() }.getOrDefault(0L)
        }

        context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getLong(index)
            }
        }
        return 0L
    }

    private fun isHdr(retriever: MediaMetadataRetriever): Boolean {
        val colorStandard = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_COLOR_STANDARD)
        return colorStandard != null && colorStandard != "1"
    }

    private fun isTenBit(retriever: MediaMetadataRetriever): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return false
        }
        val bits = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITS_PER_SAMPLE)
        return bits?.toIntOrNull()?.let { it > 8 } == true
    }
}

private fun MediaMetadataRetriever.extractInt(key: Int): Int {
    return extractMetadata(key)?.toIntOrNull() ?: 0
}

private fun MediaMetadataRetriever.extractIntOrNull(key: Int): Int? {
    return extractMetadata(key)?.toFloatOrNull()?.toInt()
}

private fun MediaMetadataRetriever.extractLong(key: Int): Long {
    return extractMetadata(key)?.toLongOrNull() ?: 0L
}

