package dev.enb.compressi.core

import android.net.Uri
import java.io.File

data class CompressionRequest(
    val inputUri: Uri,
    val outputDirectory: File,
    val outputFileName: String = "compressed_${System.currentTimeMillis()}.mp4",
    val preset: CompressionPreset = CompressionPreset.BALANCED,
    val maxResolutionCap: Int? = 1080,
) {
    init {
        require(outputFileName.endsWith(".mp4")) { "Output file name must end with .mp4" }
    }
}

