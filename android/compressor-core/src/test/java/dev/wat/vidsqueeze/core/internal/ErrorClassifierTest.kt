package dev.wat.vidsqueeze.core.internal

import com.google.common.truth.Truth.assertThat
import dev.wat.vidsqueeze.core.CompressionErrorCode
import kotlinx.coroutines.CancellationException
import org.junit.Test
import java.io.FileNotFoundException
import java.io.IOException

class ErrorClassifierTest {

    private val classifier = ErrorClassifier()

    @Test
    fun `maps cancellation to cancelled`() {
        val failure = classifier.classify(CancellationException("stop"))

        assertThat(failure.code).isEqualTo(CompressionErrorCode.CANCELLED)
    }

    @Test
    fun `maps file not found to unsupported input`() {
        val failure = classifier.classify(FileNotFoundException("missing"))

        assertThat(failure.code).isEqualTo(CompressionErrorCode.UNSUPPORTED_INPUT)
    }

    @Test
    fun `maps io exception to io failed`() {
        val failure = classifier.classify(IOException("disk"))

        assertThat(failure.code).isEqualTo(CompressionErrorCode.IO_FAILED)
    }

    @Test
    fun `maps illegal state to codec unavailable`() {
        val failure = classifier.classify(IllegalStateException("codec"))

        assertThat(failure.code).isEqualTo(CompressionErrorCode.CODEC_UNAVAILABLE)
    }
}

