package dev.wat.vidsqueeze.core.internal

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import dev.wat.vidsqueeze.core.OutputCodec
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@OptIn(UnstableApi::class)
internal class TransformerRunner(
    private val context: Context,
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    suspend fun run(
        source: SourceVideoInfo,
        plan: CompressionPlan,
        onProgress: (Int) -> Unit,
        cancellationSignal: AtomicBoolean,
    ): ExportResult = suspendCancellableCoroutine { continuation ->
        mainHandler.post {
            startOnMainThread(source, plan, onProgress, cancellationSignal, continuation)
        }
    }

    private fun startOnMainThread(
        source: SourceVideoInfo,
        plan: CompressionPlan,
        onProgress: (Int) -> Unit,
        cancellationSignal: AtomicBoolean,
        continuation: CancellableContinuation<ExportResult>,
    ) {
        val outputFile = File(plan.outputDirectory, plan.outputFileName)
        outputFile.parentFile?.mkdirs()

        val transformer = buildTransformer(plan, continuation, cancellationSignal)
        val progressHolder = ProgressHolder()
        val progressPoller = object : Runnable {
            override fun run() {
                if (cancellationSignal.get()) {
                    transformer.cancel()
                    return
                }
                val progressState = transformer.getProgress(progressHolder)
                if (progressState == Transformer.PROGRESS_STATE_AVAILABLE) {
                    onProgress(progressHolder.progress)
                }
                if (!continuation.isCompleted) {
                    mainHandler.postDelayed(this, plan.progressIntervalMs)
                }
            }
        }

        continuation.invokeOnCancellation {
            cancellationSignal.set(true)
            mainHandler.post { transformer.cancel() }
        }

        val editedMediaItem = EditedMediaItem.Builder(MediaItem.fromUri(source.uri))
            .setRemoveAudio(plan.removeAudio)
            .setEffects(
                Effects(
                    emptyList<AudioProcessor>(),
                    buildVideoEffects(plan),
                )
            )
            .build()

        mainHandler.post(progressPoller)
        transformer.start(editedMediaItem, outputFile.absolutePath)
    }

    private fun buildTransformer(
        plan: CompressionPlan,
        continuation: CancellableContinuation<ExportResult>,
        cancellationSignal: AtomicBoolean,
    ): Transformer {
        val requestedVideoSettings = VideoEncoderSettings.Builder()
            .setBitrate(plan.targetBitrate)
            .build()

        val encoderFactory = DefaultEncoderFactory.Builder(context)
            .setEnableFallback(true)
            .setRequestedVideoEncoderSettings(requestedVideoSettings)
            .apply {
                plan.audioBitrate?.let {
                    setRequestedAudioEncoderSettings(
                        AudioEncoderSettings.Builder()
                            .setBitrate(it)
                            .build()
                    )
                }
            }
            .build()

        return Transformer.Builder(context)
            .setEncoderFactory(encoderFactory)
            .setVideoMimeType(
                when (plan.codec) {
                    OutputCodec.AVC -> MimeTypes.VIDEO_H264
                    OutputCodec.HEVC -> MimeTypes.VIDEO_H265
                }
            )
            .apply {
                if (plan.transcodeAudio) {
                    setAudioMimeType(MimeTypes.AUDIO_AAC)
                }
            }
            .addListener(
                object : Transformer.Listener {
                    override fun onCompleted(
                        composition: androidx.media3.transformer.Composition,
                        exportResult: ExportResult,
                    ) {
                        if (!continuation.isCompleted) {
                            continuation.resume(exportResult)
                        }
                    }

                    override fun onError(
                        composition: androidx.media3.transformer.Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        if (cancellationSignal.get()) {
                            continuation.resumeWithException(CancellationException(exportException.message))
                            return
                        }
                        if (!continuation.isCompleted) {
                            continuation.resumeWithException(exportException)
                        }
                    }
                }
            )
            .build()
    }

    private fun buildVideoEffects(plan: CompressionPlan): List<Effect> {
        val targetHeight = plan.targetHeight ?: return emptyList()
        return listOf(Presentation.createForHeight(targetHeight))
    }
}
