package dev.enb.compressi.core.internal

import dev.enb.compressi.core.CompressionErrorCode
import dev.enb.compressi.core.CompressionFailure
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.CancellationException

internal class ErrorClassifier {

    fun classify(throwable: Throwable): CompressionFailure {
        val code = when (throwable) {
            is CancellationException -> CompressionErrorCode.CANCELLED
            is FileNotFoundException -> CompressionErrorCode.UNSUPPORTED_INPUT
            is IOException -> CompressionErrorCode.IO_FAILED
            is IllegalArgumentException -> CompressionErrorCode.UNSUPPORTED_INPUT
            is IllegalStateException -> CompressionErrorCode.CODEC_UNAVAILABLE
            else -> CompressionErrorCode.TRANSFORM_FAILED
        }
        return CompressionFailure(
            code = code,
            message = throwable.message ?: code.name,
            cause = throwable,
        )
    }
}

