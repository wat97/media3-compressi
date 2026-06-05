package dev.enb.compressi.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.util.UnstableApi
import dev.enb.compressi.core.internal.CapabilityResolver
import dev.enb.compressi.core.internal.CompressionPlan
import dev.enb.compressi.core.internal.CompressionPolicyEngine
import dev.enb.compressi.core.internal.ErrorClassifier
import dev.enb.compressi.core.internal.FallbackPlanner
import dev.enb.compressi.core.internal.OutputValidator
import dev.enb.compressi.core.internal.SourceInspector
import dev.enb.compressi.core.internal.TransformerRunner
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

@OptIn(UnstableApi::class)
class VideoCompressor private constructor(
    private val scope: CoroutineScope,
    private val sourceInspector: SourceInspector,
    private val capabilityResolver: CapabilityResolver,
    private val fallbackPlanner: FallbackPlanner,
    private val transformerRunner: TransformerRunner,
    private val outputValidator: OutputValidator,
    private val errorClassifier: ErrorClassifier,
) {
    constructor(
        context: Context,
        scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    ) : this(
        scope = scope,
        sourceInspector = SourceInspector(context.applicationContext),
        capabilityResolver = CapabilityResolver(),
        fallbackPlanner = FallbackPlanner(CompressionPolicyEngine()),
        transformerRunner = TransformerRunner(context.applicationContext),
        outputValidator = OutputValidator(),
        errorClassifier = ErrorClassifier(),
    )

    private val mainHandler = Handler(Looper.getMainLooper())

    fun start(
        request: CompressionRequest,
        listener: CompressionListener,
    ): CompressionHandle {
        val cancelled = AtomicBoolean(false)
        val job = scope.launch {
            dispatch(listener) { onStateChanged(CompressionState.Preparing) }

            runCatching {
                require(request.outputDirectory.exists() || request.outputDirectory.mkdirs()) {
                    "Output directory does not exist and could not be created"
                }

                val source = sourceInspector.inspect(request.inputUri)
                val capability = capabilityResolver.resolve()
                val attempts = fallbackPlanner.buildAttemptPlans(request, source, capability)

                var lastFailure: Throwable? = null
                attempts.forEachIndexed { index, plan ->
                    ensureNotCancelled(cancelled)
                    val tempFile = File(plan.outputDirectory, "${plan.outputFileName.removeSuffix(".mp4")}.tmp.mp4")
                    tempFile.delete()

                    try {
                        dispatch(listener) { onStateChanged(CompressionState.Transcoding(progressPercent = 0)) }
                        transformerRunner.run(
                            source = source,
                            plan = plan.copy(outputFileName = tempFile.name),
                            onProgress = { progress ->
                                dispatch(listener) { onStateChanged(CompressionState.Transcoding(progress)) }
                            },
                            cancellationSignal = cancelled,
                        )

                        dispatch(listener) { onStateChanged(CompressionState.Finalizing) }
                        outputValidator.validate(tempFile, source)

                        val useOriginalSource = shouldKeepOriginalSource(request, source, tempFile)
                        val outputFile = File(plan.outputDirectory, plan.outputFileName)
                        if (outputFile.exists()) {
                            outputFile.delete()
                        }

                        val deliveredFile = if (useOriginalSource) {
                            tempFile.delete()
                            source.uri.takeIf { it.scheme == "file" }?.path?.let(::File)
                                ?: throw IllegalStateException("Original source file is not accessible as a file")
                        } else {
                            check(tempFile.renameTo(outputFile)) { "Failed to move temp output into final location" }
                            outputFile
                        }

                        val success = CompressionSuccess(
                            outputFile = deliveredFile,
                            outputSizeBytes = deliveredFile.length(),
                            sourceSizeBytes = source.fileSizeBytes,
                            durationMs = source.durationMs,
                            codec = when (plan.codec) {
                                OutputCodec.AVC -> OutputCodec.AVC
                                OutputCodec.HEVC -> OutputCodec.HEVC
                            },
                            targetHeight = plan.targetHeight,
                            targetBitrate = plan.targetBitrate,
                            attempts = index + 1,
                            usedOriginalSource = useOriginalSource,
                        )
                        dispatch(listener) { onStateChanged(CompressionState.Completed) }
                        dispatch(listener) { onSuccess(success) }
                        return@launch
                    } catch (throwable: Throwable) {
                        tempFile.delete()
                        lastFailure = throwable
                    }
                }

                throw lastFailure ?: IllegalStateException("Compression failed with no root cause")
            }.onFailure { throwable ->
                val failure = if (throwable is CancellationException || cancelled.get()) {
                    CompressionFailure(
                        code = CompressionErrorCode.CANCELLED,
                        message = "Compression cancelled",
                        cause = throwable,
                    )
                } else {
                    errorClassifier.classify(throwable)
                }

                dispatch(listener) {
                    onStateChanged(
                    when (failure.code) {
                        CompressionErrorCode.CANCELLED -> CompressionState.Cancelled
                        else -> CompressionState.Failed(failure)
                    }
                )
                }
                dispatch(listener) { onFailure(failure) }
            }
        }

        return object : CompressionHandle {
            override fun cancel() {
                cancelled.set(true)
                job.cancel(CancellationException("Cancelled by caller"))
            }
        }
    }

    fun shutdown() {
        scope.cancel()
    }

    private fun ensureNotCancelled(cancelled: AtomicBoolean) {
        if (cancelled.get()) {
            throw CancellationException("Compression cancelled")
        }
    }

    private fun shouldKeepOriginalSource(
        request: CompressionRequest,
        source: dev.enb.compressi.core.internal.SourceVideoInfo,
        compressedFile: File,
    ): Boolean {
        if (!request.keepOriginalIfLarger) {
            return false
        }
        if (source.fileSizeBytes <= 0L || compressedFile.length() <= 0L) {
            return false
        }
        return compressedFile.length() >= source.fileSizeBytes && request.inputUri.scheme == "file"
    }

    private fun dispatch(listener: CompressionListener, block: CompressionListener.() -> Unit) {
        mainHandler.post { listener.block() }
    }
}
