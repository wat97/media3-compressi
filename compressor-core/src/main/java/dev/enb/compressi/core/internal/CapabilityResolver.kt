package dev.enb.compressi.core.internal

import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build

internal class CapabilityResolver {

    @Volatile
    private var cached: CapabilitySnapshot? = null

    fun resolve(): CapabilitySnapshot {
        cached?.let { return it }

        val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos
        val snapshot = CapabilitySnapshot(
            apiLevel = Build.VERSION.SDK_INT,
            hevcEncoderAvailable = codecs.supportsVideoEncoder("video/hevc"),
            avcEncoderAvailable = codecs.supportsVideoEncoder("video/avc"),
        )
        cached = snapshot
        return snapshot
    }
}

private fun Array<MediaCodecInfo>.supportsVideoEncoder(mimeType: String): Boolean {
    return any { codec ->
        codec.isEncoder && codec.supportedTypes.any { it.equals(mimeType, ignoreCase = true) }
    }
}

