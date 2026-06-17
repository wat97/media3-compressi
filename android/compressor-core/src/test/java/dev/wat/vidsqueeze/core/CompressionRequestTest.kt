package dev.wat.vidsqueeze.core

import android.net.Uri
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.mockito.Mockito.mock
import java.io.File

class CompressionRequestTest {

    @Test
    fun `builder creates request with custom values`() {
        val request = CompressionRequest.builder(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
        ).apply {
            outputFileName = "custom.mp4"
            preset = CompressionPreset.SMALL_SIZE
            maxResolutionCap = 720
            allowHevc = false
            keepAudio = false
            keepOriginalIfLarger = false
            forceCodec = ForceCodec.AVC
            maxBitrate = 2_000_000
            progressIntervalMs = 500L
        }.build()

        assertThat(request.outputFileName).isEqualTo("custom.mp4")
        assertThat(request.preset).isEqualTo(CompressionPreset.SMALL_SIZE)
        assertThat(request.maxResolutionCap).isEqualTo(720)
        assertThat(request.allowHevc).isFalse()
        assertThat(request.keepAudio).isFalse()
        assertThat(request.keepOriginalIfLarger).isFalse()
        assertThat(request.forceCodec).isEqualTo(ForceCodec.AVC)
        assertThat(request.maxBitrate).isEqualTo(2_000_000)
        assertThat(request.progressIntervalMs).isEqualTo(500L)
    }

    @Test
    fun `dsl helper builds request`() {
        val request = buildCompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
        ) {
            preset = CompressionPreset.QUALITY
            maxResolutionCap = null
        }

        assertThat(request.preset).isEqualTo(CompressionPreset.QUALITY)
        assertThat(request.maxResolutionCap).isNull()
    }

    @Test
    fun `rejects unsafe output file names`() {
        val unsafeNames = listOf(
            "",
            "../escape.mp4",
            "nested/escape.mp4",
            "nested\\escape.mp4",
            "/tmp/escape.mp4",
            "escape.mov",
        )

        unsafeNames.forEach { outputFileName ->
            runCatching {
                CompressionRequest(
                    inputUri = mock(Uri::class.java),
                    outputDirectory = File("build/tmp"),
                    outputFileName = outputFileName,
                )
            }.also { result ->
                assertThat(result.isFailure).isTrue()
            }
        }
    }

}
