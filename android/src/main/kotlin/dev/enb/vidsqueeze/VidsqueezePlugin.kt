package dev.enb.vidsqueeze

import android.content.Context
import android.net.Uri
import dev.enb.compressi.core.CompressionFailure
import dev.enb.compressi.core.CompressionListener
import dev.enb.compressi.core.CompressionPreset
import dev.enb.compressi.core.CompressionRequest
import dev.enb.compressi.core.CompressionState
import dev.enb.compressi.core.CompressionSuccess
import dev.enb.compressi.core.ForceCodec
import dev.enb.compressi.core.VideoCompressor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

class VidsqueezePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var applicationContext: Context? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val activeTaskId = AtomicReference<String?>(null)
    private var compressor: VideoCompressor? = null
    private var activeHandle: dev.enb.compressi.core.CompressionHandle? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        compressor = VideoCompressor(binding.applicationContext)
        methodChannel = MethodChannel(binding.binaryMessenger, "vidsqueeze/methods").also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, "vidsqueeze/events").also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        activeHandle?.cancel()
        compressor?.shutdown()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        applicationContext = null
        compressor = null
        eventSink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "compress" -> compress(call, result)
            "cancel" -> cancel(call, result)
            else -> result.notImplemented()
        }
    }

    private fun compress(call: MethodCall, result: MethodChannel.Result) {
        if (activeHandle != null) {
            result.error("busy", "Another compression task is already running", null)
            return
        }

        val context = applicationContext ?: run {
            result.error("no_context", "Plugin is not attached to an Android context", null)
            return
        }
        val compressor = compressor ?: run {
            result.error("no_compressor", "Video compressor is unavailable", null)
            return
        }

        val args = call.arguments as? Map<*, *> ?: run {
            result.error("bad_args", "compress expects a map payload", null)
            return
        }

        val taskId = args["taskId"] as? String ?: UUID.randomUUID().toString()
        val request = runCatching { args.toCompressionRequest(taskId) }.getOrElse { throwable ->
            result.error("bad_request", throwable.message, null)
            return
        }

        activeTaskId.set(taskId)
        activeHandle = compressor.start(
            request,
            object : CompressionListener {
                override fun onStateChanged(state: CompressionState) {
                    eventSink?.success(state.toMap(taskId))
                }

                override fun onSuccess(resultValue: CompressionSuccess) {
                    activeHandle = null
                    activeTaskId.set(null)
                    result.success(resultValue.toMap(taskId))
                }

                override fun onFailure(failure: CompressionFailure) {
                    activeHandle = null
                    activeTaskId.set(null)
                    result.error(failure.code.name.lowercase(), failure.message, mapOf("taskId" to taskId))
                }
            },
        )
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val taskId = (call.arguments as? Map<*, *>)?.get("taskId") as? String
        if (taskId != null && taskId == activeTaskId.get()) {
            activeHandle?.cancel()
            activeHandle = null
            activeTaskId.set(null)
        }
        result.success(null)
    }
}

private fun Map<*, *>.toCompressionRequest(taskId: String): CompressionRequest {
    val inputPath = get("inputPath") as? String ?: error("inputPath is required")
    val outputDirectoryPath = get("outputDirectoryPath") as? String ?: error("outputDirectoryPath is required")
    val outputFileName = get("outputFileName") as? String ?: "compressed_${taskId}.mp4"
    val preset = CompressionPreset.valueOf(
        ((get("preset") as? String) ?: "balanced").toCompressionPresetName(),
    )
    val forceCodec = ForceCodec.valueOf(
        ((get("forceCodec") as? String) ?: "auto").uppercase(),
    )

    return CompressionRequest(
        inputUri = Uri.parse(inputPath),
        outputDirectory = File(outputDirectoryPath),
        outputFileName = outputFileName,
        preset = preset,
        maxResolutionCap = (get("maxResolutionCap") as? Number)?.toInt(),
        allowHevc = get("allowHevc") as? Boolean ?: true,
        keepAudio = get("keepAudio") as? Boolean ?: true,
        keepOriginalIfLarger = get("keepOriginalIfLarger") as? Boolean ?: true,
        forceCodec = forceCodec,
        maxBitrate = (get("maxBitrate") as? Number)?.toInt(),
        progressIntervalMs = (get("progressIntervalMs") as? Number)?.toLong() ?: 250L,
    )
}

private fun String.toCompressionPresetName(): String {
    return when (this.lowercase()) {
        "quality" -> "QUALITY"
        "small_size" -> "SMALL_SIZE"
        else -> "BALANCED"
    }
}

private fun CompressionState.toMap(taskId: String): Map<String, Any?> {
    return when (this) {
        CompressionState.Preparing -> mapOf("taskId" to taskId, "phase" to "preparing")
        CompressionState.Finalizing -> mapOf("taskId" to taskId, "phase" to "finalizing")
        CompressionState.Completed -> mapOf("taskId" to taskId, "phase" to "completed")
        CompressionState.Cancelled -> mapOf("taskId" to taskId, "phase" to "cancelled")
        is CompressionState.Transcoding -> mapOf(
            "taskId" to taskId,
            "phase" to "transcoding",
            "progressPercent" to progressPercent,
        )
        is CompressionState.Failed -> mapOf(
            "taskId" to taskId,
            "phase" to "failed",
            "code" to failure.code.name.lowercase(),
            "message" to failure.message,
        )
    }
}

private fun CompressionSuccess.toMap(taskId: String): Map<String, Any?> {
    return mapOf(
        "taskId" to taskId,
        "outputPath" to outputFile.absolutePath,
        "outputSizeBytes" to outputSizeBytes,
        "sourceSizeBytes" to sourceSizeBytes,
        "durationMs" to durationMs,
        "codec" to codec.name.lowercase(),
        "targetHeight" to targetHeight,
        "targetBitrate" to targetBitrate,
        "attempts" to attempts,
        "usedOriginalSource" to usedOriginalSource,
    )
}

