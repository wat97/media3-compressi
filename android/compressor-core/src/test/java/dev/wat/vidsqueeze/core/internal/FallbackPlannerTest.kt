package dev.wat.vidsqueeze.core.internal

import android.net.Uri
import com.google.common.truth.Truth.assertThat
import dev.wat.vidsqueeze.core.CompressionRequest
import dev.wat.vidsqueeze.core.ForceCodec
import dev.wat.vidsqueeze.core.OutputCodec
import org.junit.Test
import org.mockito.Mockito.mock
import java.io.File

class FallbackPlannerTest {

    private val planner = FallbackPlanner(CompressionPolicyEngine())

    @Test
    fun `builds hevc then avc retry on api 34`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
        )
        val source = fakeSource(width = 1920, height = 1080)
        val capability = CapabilitySnapshot(apiLevel = 34, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val attempts = planner.buildAttemptPlans(request, source, capability)

        assertThat(attempts).hasSize(2)
        assertThat(attempts[0].codec).isEqualTo(OutputCodec.HEVC)
        assertThat(attempts[1].codec).isEqualTo(OutputCodec.AVC)
    }

    @Test
    fun `builds legacy avc retry with lower height and bitrate`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
            maxResolutionCap = 1080,
        )
        val source = fakeSource(width = 1920, height = 1440, bitrate = 9_000_000)
        val capability = CapabilitySnapshot(apiLevel = 28, hevcEncoderAvailable = false, avcEncoderAvailable = true)

        val attempts = planner.buildAttemptPlans(request, source, capability)

        assertThat(attempts).hasSize(2)
        assertThat(attempts[0].codec).isEqualTo(OutputCodec.AVC)
        assertThat(attempts[1].codec).isEqualTo(OutputCodec.AVC)
        assertThat(attempts[1].targetHeight).isEqualTo(720)
        assertThat(attempts[1].targetBitrate).isLessThan(attempts[0].targetBitrate)
    }

    @Test
    fun `does not add retry for modern avc first plan`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
        )
        val source = fakeSource(width = 1920, height = 1080, isHdr = true)
        val capability = CapabilitySnapshot(apiLevel = 33, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val attempts = planner.buildAttemptPlans(request, source, capability)

        assertThat(attempts).hasSize(1)
        assertThat(attempts[0].codec).isEqualTo(OutputCodec.AVC)
    }

    @Test
    fun `does not add retry when codec is forced`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
            forceCodec = ForceCodec.HEVC,
        )
        val source = fakeSource(width = 1920, height = 1080)
        val capability = CapabilitySnapshot(apiLevel = 34, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val attempts = planner.buildAttemptPlans(request, source, capability)

        assertThat(attempts).hasSize(1)
        assertThat(attempts[0].codec).isEqualTo(OutputCodec.HEVC)
    }

    private fun fakeSource(
        width: Int,
        height: Int,
        bitrate: Int = 8_000_000,
        isHdr: Boolean = false,
    ) = SourceVideoInfo(
        uri = mock(Uri::class.java),
        mimeType = "video/mp4",
        width = width,
        height = height,
        frameRate = 30,
        bitrate = bitrate,
        durationMs = 10_000L,
        rotationDegrees = 0,
        fileSizeBytes = 100_000_000L,
        hasAudio = true,
        isHdr = isHdr,
        isTenBit = false,
    )
}
