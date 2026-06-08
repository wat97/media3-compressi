package dev.enb.compressi.core.internal

import android.net.Uri
import com.google.common.truth.Truth.assertThat
import dev.enb.compressi.core.CompressionPreset
import dev.enb.compressi.core.CompressionRequest
import dev.enb.compressi.core.ForceCodec
import dev.enb.compressi.core.OutputCodec
import org.junit.Test
import org.mockito.Mockito.mock
import java.io.File

class CompressionPolicyEngineTest {

    private val engine = CompressionPolicyEngine()

    @Test
    fun `prefers hevc on api 34 when encoder exists and source safe`() {
        val source = fakeSource(width = 1920, height = 1080)
        val capability = CapabilitySnapshot(apiLevel = 34, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val codec = engine.chooseCodec(
            source,
            capability,
            CompressionRequest(inputUri = mock(Uri::class.java), outputDirectory = File("build/tmp")),
        )

        assertThat(codec).isEqualTo(OutputCodec.HEVC)
    }

    @Test
    fun `falls back to avc for hdr input`() {
        val source = fakeSource(width = 1920, height = 1080, isHdr = true)
        val capability = CapabilitySnapshot(apiLevel = 34, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val codec = engine.chooseCodec(
            source,
            capability,
            CompressionRequest(inputUri = mock(Uri::class.java), outputDirectory = File("build/tmp")),
        )

        assertThat(codec).isEqualTo(OutputCodec.AVC)
    }

    @Test
    fun `caps 4k input to 1080p height`() {
        val source = fakeSource(width = 3840, height = 2160)

        val targetHeight = engine.chooseTargetHeight(source, maxResolutionCap = 1080)

        assertThat(targetHeight).isEqualTo(1080)
    }

    @Test
    fun `balanced hevc bitrate lower than avc`() {
        val source = fakeSource(width = 1920, height = 1080, bitrate = 10_000_000)

        val hevc = engine.chooseTargetBitrate(source, OutputCodec.HEVC, CompressionPreset.BALANCED, null, null)
        val avc = engine.chooseTargetBitrate(source, OutputCodec.AVC, CompressionPreset.BALANCED, null, null)

        assertThat(hevc).isLessThan(avc)
    }

    @Test
    fun `quality preset keeps higher bitrate than small size`() {
        val source = fakeSource(width = 1920, height = 1080, bitrate = 10_000_000)

        val quality = engine.chooseTargetBitrate(source, OutputCodec.AVC, CompressionPreset.QUALITY, null, null)
        val small = engine.chooseTargetBitrate(source, OutputCodec.AVC, CompressionPreset.SMALL_SIZE, null, null)

        assertThat(quality).isGreaterThan(small)
    }

    @Test
    fun `plan keeps 720p sources at original height`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
        )
        val source = fakeSource(width = 1280, height = 720)
        val capability = CapabilitySnapshot(apiLevel = 29, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val plan = engine.plan(request, source, capability)

        assertThat(plan.targetHeight).isNull()
    }

    @Test
    fun `force codec overrides auto selection`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
            forceCodec = ForceCodec.AVC,
        )
        val source = fakeSource(width = 1920, height = 1080)
        val capability = CapabilitySnapshot(apiLevel = 34, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val plan = engine.plan(request, source, capability)

        assertThat(plan.codec).isEqualTo(OutputCodec.AVC)
    }

    @Test
    fun `keep audio false removes audio from plan`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
            keepAudio = false,
        )
        val source = fakeSource(width = 1280, height = 720)
        val capability = CapabilitySnapshot(apiLevel = 29, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val plan = engine.plan(request, source, capability)

        assertThat(plan.removeAudio).isTrue()
        assertThat(plan.transcodeAudio).isFalse()
        assertThat(plan.audioBitrate).isNull()
    }

    @Test
    fun `max bitrate caps computed bitrate`() {
        val request = CompressionRequest(
            inputUri = mock(Uri::class.java),
            outputDirectory = File("build/tmp"),
            maxBitrate = 2_500_000,
        )
        val source = fakeSource(width = 1920, height = 1080, bitrate = 10_000_000)
        val capability = CapabilitySnapshot(apiLevel = 29, hevcEncoderAvailable = true, avcEncoderAvailable = true)

        val plan = engine.plan(request, source, capability)

        assertThat(plan.targetBitrate).isAtMost(2_500_000)
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
