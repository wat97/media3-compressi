package dev.enb.vidsqueeze

import android.content.Context
import android.net.Uri
import dev.enb.compressi.core.CompressionFailure
import dev.enb.compressi.core.CompressionHandle
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
    private var activeHandle: CompressionHandle? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        compressor = VideoCompressor(binding.applicationContext)
        methodChannel = MethodChannel(binding.binaryMessenger, FlutterContract.METHODS_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, FlutterContract.EVENTS_CHANNEL).also {
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
            FlutterContract.METHOD_COMPRESS -> compress(call, result)
            FlutterContract.METHOD_CANCEL -> cancel(call, result)
            else -> result.notImplemented()
        }
    }

    private fun compress(call: MethodCall, result: MethodChannel.Result) {
        if (activeHandle != null) {
            result.error(
                FlutterContract.ERROR_BUSY,
                "Another compression task is already running",
                null,
            )
            return
        }

        applicationContext ?: run {
            result.error(
                FlutterContract.ERROR_NO_CONTEXT,
                "Plugin is not attached to an Android context",
                null,
            )
            return
        }
        val compressor = compressor ?: run {
            result.error(
                FlutterContract.ERROR_NO_COMPRESSOR,
                "Video compressor is unavailable",
                null,
            )
            return
        }

        val args = call.arguments as? Map<*, *> ?: run {
            result.error(
                FlutterContract.ERROR_BAD_ARGS,
                "compress expects a map payload",
                null,
            )
            return
        }

        val taskId = args.stringOrNull(FlutterContract.KEY_TASK_ID)
            ?.takeIf { it.isNotBlank() }
            ?: UUID.randomUUID().toString()
        val request = runCatching { args.toCompressionRequest(taskId) }.getOrElse { throwable ->
            val failure = throwable as? CompressionFailure
            result.error(
                failure?.code?.name?.lowercase() ?: FlutterContract.ERROR_BAD_REQUEST,
                throwable.message,
                mapOf(FlutterContract.KEY_TASK_ID to taskId),
            )
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
                    result.error(
                        failure.code.name.lowercase(),
                        failure.message,
                        mapOf(FlutterContract.KEY_TASK_ID to taskId),
                    )
                }
            },
        )
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val taskId = (call.arguments as? Map<*, *>)?.stringOrNull(FlutterContract.KEY_TASK_ID)
        if (taskId == null || taskId == activeTaskId.get()) {
            activeHandle?.cancel()
            activeHandle = null
            activeTaskId.set(null)
        }
        result.success(null)
    }
}

private fun Map<*, *>.toCompressionRequest(taskId: String): CompressionRequest {
    val inputPath = stringOrNull(FlutterContract.KEY_INPUT_PATH)
        ?: error("${FlutterContract.KEY_INPUT_PATH} is required")
    val outputDirectoryPath = stringOrNull(FlutterContract.KEY_OUTPUT_DIRECTORY_PATH)
        ?: error("${FlutterContract.KEY_OUTPUT_DIRECTORY_PATH} is required")
    val outputFileName = stringOrNull(FlutterContract.KEY_OUTPUT_FILE_NAME)
        ?.takeIf { it.isNotBlank() }
        ?: "compressed_${taskId}.mp4"
    val preset = CompressionPreset.valueOf(
        (stringOrNull(FlutterContract.KEY_PRESET) ?: "balanced").toCompressionPresetName(),
    )
    val forceCodec = ForceCodec.valueOf(
        (stringOrNull(FlutterContract.KEY_FORCE_CODEC) ?: "auto").uppercase(),
    )

    return CompressionRequest(
        inputUri = Uri.parse(inputPath),
        outputDirectory = outputDirectoryPath.toPlatformFile(),
        outputFileName = outputFileName,
        preset = preset,
        maxResolutionCap = (get(FlutterContract.KEY_MAX_RESOLUTION_CAP) as? Number)?.toInt(),
        allowHevc = get(FlutterContract.KEY_ALLOW_HEVC) as? Boolean ?: true,
        keepAudio = get(FlutterContract.KEY_KEEP_AUDIO) as? Boolean ?: true,
        keepOriginalIfLarger = get(FlutterContract.KEY_KEEP_ORIGINAL_IF_LARGER) as? Boolean ?: true,
        forceCodec = forceCodec,
        maxBitrate = (get(FlutterContract.KEY_MAX_BITRATE) as? Number)?.toInt(),
        progressIntervalMs = (get(FlutterContract.KEY_PROGRESS_INTERVAL_MS) as? Number)?.toLong() ?: 250L,
    )
}

private fun String.toCompressionPresetName(): String {
    return when (lowercase()) {
        "quality" -> "QUALITY"
        "small_size" -> "SMALL_SIZE"
        else -> "BALANCED"
    }
}

private fun CompressionState.toMap(taskId: String): Map<String, Any?> {
    return when (this) {
        CompressionState.Preparing -> mapOf(
            FlutterContract.KEY_TASK_ID to taskId,
            FlutterContract.KEY_PHASE to FlutterContract.PHASE_PREPARING,
        )
        CompressionState.Finalizing -> mapOf(
            FlutterContract.KEY_TASK_ID to taskId,
            FlutterContract.KEY_PHASE to FlutterContract.PHASE_FINALIZING,
        )
        CompressionState.Completed -> mapOf(
            FlutterContract.KEY_TASK_ID to taskId,
            FlutterContract.KEY_PHASE to FlutterContract.PHASE_COMPLETED,
        )
        CompressionState.Cancelled -> mapOf(
            FlutterContract.KEY_TASK_ID to taskId,
            FlutterContract.KEY_PHASE to FlutterContract.PHASE_CANCELLED,
        )
        is CompressionState.Transcoding -> mapOf(
            FlutterContract.KEY_TASK_ID to taskId,
            FlutterContract.KEY_PHASE to FlutterContract.PHASE_TRANSCODING,
            FlutterContract.KEY_PROGRESS_PERCENT to progressPercent,
        )
        is CompressionState.Failed -> mapOf(
            FlutterContract.KEY_TASK_ID to taskId,
            FlutterContract.KEY_PHASE to FlutterContract.PHASE_FAILED,
            FlutterContract.KEY_CODE to failure.code.name.lowercase(),
            FlutterContract.KEY_MESSAGE to failure.message,
        )
    }
}

private fun CompressionSuccess.toMap(taskId: String): Map<String, Any?> {
    return mapOf(
        FlutterContract.KEY_TASK_ID to taskId,
        FlutterContract.KEY_OUTPUT_PATH to outputFile.absolutePath,
        FlutterContract.KEY_OUTPUT_SIZE_BYTES to outputSizeBytes,
        FlutterContract.KEY_SOURCE_SIZE_BYTES to sourceSizeBytes,
        FlutterContract.KEY_DURATION_MS to durationMs,
        FlutterContract.KEY_CODEC to codec.name.lowercase(),
        FlutterContract.KEY_TARGET_HEIGHT to targetHeight,
        FlutterContract.KEY_TARGET_BITRATE to targetBitrate,
        FlutterContract.KEY_ATTEMPTS to attempts,
        FlutterContract.KEY_USED_ORIGINAL_SOURCE to usedOriginalSource,
    )
}

private fun Map<*, *>.stringOrNull(key: String): String? = get(key) as? String

private fun String.toPlatformFile(): File {
    return if (startsWith("file://")) {
        File(requireNotNull(Uri.parse(this).path) { "Invalid file URI: $this" })
    } else {
        File(this)
    }
}

private object FlutterContract {
    const val METHODS_CHANNEL = "vidsqueeze/methods"
    const val EVENTS_CHANNEL = "vidsqueeze/events"

    const val METHOD_COMPRESS = "compress"
    const val METHOD_CANCEL = "cancel"

    const val KEY_TASK_ID = "taskId"
    const val KEY_INPUT_PATH = "inputPath"
    const val KEY_OUTPUT_DIRECTORY_PATH = "outputDirectoryPath"
    const val KEY_OUTPUT_FILE_NAME = "outputFileName"
    const val KEY_PRESET = "preset"
    const val KEY_MAX_RESOLUTION_CAP = "maxResolutionCap"
    const val KEY_ALLOW_HEVC = "allowHevc"
    const val KEY_KEEP_AUDIO = "keepAudio"
    const val KEY_KEEP_ORIGINAL_IF_LARGER = "keepOriginalIfLarger"
    const val KEY_FORCE_CODEC = "forceCodec"
    const val KEY_MAX_BITRATE = "maxBitrate"
    const val KEY_PROGRESS_INTERVAL_MS = "progressIntervalMs"
    const val KEY_PHASE = "phase"
    const val KEY_PROGRESS_PERCENT = "progressPercent"
    const val KEY_CODE = "code"
    const val KEY_MESSAGE = "message"
    const val KEY_OUTPUT_PATH = "outputPath"
    const val KEY_OUTPUT_SIZE_BYTES = "outputSizeBytes"
    const val KEY_SOURCE_SIZE_BYTES = "sourceSizeBytes"
    const val KEY_DURATION_MS = "durationMs"
    const val KEY_CODEC = "codec"
    const val KEY_TARGET_HEIGHT = "targetHeight"
    const val KEY_TARGET_BITRATE = "targetBitrate"
    const val KEY_ATTEMPTS = "attempts"
    const val KEY_USED_ORIGINAL_SOURCE = "usedOriginalSource"

    const val PHASE_PREPARING = "preparing"
    const val PHASE_TRANSCODING = "transcoding"
    const val PHASE_FINALIZING = "finalizing"
    const val PHASE_COMPLETED = "completed"
    const val PHASE_FAILED = "failed"
    const val PHASE_CANCELLED = "cancelled"

    const val ERROR_BUSY = "busy"
    const val ERROR_BAD_ARGS = "bad_args"
    const val ERROR_BAD_REQUEST = "bad_request"
    const val ERROR_NO_CONTEXT = "no_context"
    const val ERROR_NO_COMPRESSOR = "no_compressor"
}
