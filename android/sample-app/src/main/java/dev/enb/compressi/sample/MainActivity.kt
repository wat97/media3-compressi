package dev.enb.compressi.sample

import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Bundle
import android.widget.ArrayAdapter
import androidx.activity.enableEdgeToEdge
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import dev.enb.compressi.core.CompressionPreset
import dev.enb.compressi.core.CompressionFailure
import dev.enb.compressi.core.CompressionHandle
import dev.enb.compressi.core.CompressionListener
import dev.enb.compressi.core.CompressionRequest
import dev.enb.compressi.core.CompressionState
import dev.enb.compressi.core.CompressionSuccess
import dev.enb.compressi.core.ForceCodec
import dev.enb.compressi.core.VideoCompressor
import dev.enb.compressi.core.buildCompressionRequest
import dev.enb.compressi.sample.databinding.ActivityMainBinding
import java.io.File

class MainActivity : ComponentActivity(), CompressionListener {

    private lateinit var binding: ActivityMainBinding
    private lateinit var compressor: VideoCompressor

    private var selectedUri: Uri? = null
    private var activeHandle: CompressionHandle? = null
    private var selectedSourceSummary: VideoSummary? = null
    private val resolutionOptions = listOf(
        ResolutionOption("Original", null),
        ResolutionOption("1080p", 1080),
        ResolutionOption("720p", 720),
        ResolutionOption("480p", 480),
    )
    private val presetOptions = listOf(
        PresetOption("Quality", CompressionPreset.QUALITY),
        PresetOption("Balanced", CompressionPreset.BALANCED),
        PresetOption("Small Size", CompressionPreset.SMALL_SIZE),
    )
    private val codecOptions = listOf(
        CodecOption("Auto", ForceCodec.AUTO),
        CodecOption("AVC", ForceCodec.AVC),
        CodecOption("HEVC", ForceCodec.HEVC),
    )

    private val picker = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            runCatching {
                contentResolver.takePersistableUriPermission(
                    uri,
                    IntentFlags.readOnly,
                )
            }
            selectedUri = uri
            selectedSourceSummary = inspectVideo(uri)
            binding.sourceValue.text = buildString {
                append(uri.toString())
                selectedSourceSummary?.let { summary ->
                    append("\n")
                    append("Resolution: ${summary.width}x${summary.height}")
                    append("\n")
                    append("Size: ${summary.sizeMb.formatMb()} MB")
                }
            }
            binding.statusValue.text = "Source selected"
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        compressor = VideoCompressor(applicationContext)
        setupPickers()
        applyEdgeToEdgeInsets()

        binding.pickSourceButton.setOnClickListener {
            picker.launch(arrayOf("video/*"))
        }
        binding.compressButton.setOnClickListener {
            startCompression()
        }
        binding.cancelButton.setOnClickListener {
            activeHandle?.cancel()
        }
    }

    override fun onDestroy() {
        activeHandle?.cancel()
        compressor.shutdown()
        super.onDestroy()
    }

    override fun onStateChanged(state: CompressionState) {
        binding.statusValue.text = when (state) {
            CompressionState.Preparing -> "Preparing"
            CompressionState.Finalizing -> "Finalizing"
            CompressionState.Completed -> "Completed"
            CompressionState.Cancelled -> "Cancelled"
            is CompressionState.Transcoding -> "Transcoding ${state.progressPercent}%"
            is CompressionState.Failed -> "Failed: ${state.failure.code}"
        }
        if (state is CompressionState.Transcoding) {
            binding.progressIndicator.progress = state.progressPercent
        }
    }

    override fun onSuccess(result: CompressionSuccess) {
        activeHandle = null
        val outputSummary = inspectVideo(Uri.fromFile(result.outputFile))
        binding.outputValue.text = buildString {
            append("Output file: ${result.outputFile.absolutePath}")
            append("\n")
            append("Codec: ${result.codec}")
            append("\n")
            append("Bitrate: ${result.targetBitrate}")
            append("\n")
            selectedSourceSummary?.let { source ->
                append("Source: ${source.width}x${source.height} | ${source.sizeMb.formatMb()} MB")
                append("\n")
            }
            outputSummary?.let { output ->
                append("Output: ${output.width}x${output.height} | ${output.sizeMb.formatMb()} MB")
                append("\n")
            }
            append("Saved: ${(result.sourceSizeBytes.toMb() - result.outputSizeBytes.toMb()).coerceAtLeast(0.0).formatMb()} MB")
        }
        binding.progressIndicator.progress = 100
    }

    override fun onFailure(failure: CompressionFailure) {
        activeHandle = null
        binding.outputValue.text = "${failure.code}: ${failure.message}"
    }

    private fun startCompression() {
        val source = selectedUri ?: run {
            binding.statusValue.text = "Pick source first"
            return
        }
        val outputDir = File(cacheDir, "compressed").apply { mkdirs() }
        val selectedResolution = resolutionOptions[binding.resolutionSpinner.selectedItemPosition]
        val selectedPreset = presetOptions[binding.presetSpinner.selectedItemPosition]
        val selectedCodec = codecOptions[binding.codecSpinner.selectedItemPosition]
        val maxBitrate = binding.maxBitrateInput.text.toString().trim()
            .takeIf { it.isNotEmpty() }
            ?.toDoubleOrNull()
            ?.times(1_000_000)
            ?.toInt()
        val progressIntervalMs = binding.progressIntervalInput.text.toString().trim()
            .toLongOrNull()
            ?.coerceAtLeast(1L)
            ?: 250L

        activeHandle = compressor.start(
            buildCompressionRequest(
                inputUri = source,
                outputDirectory = outputDir,
            ) {
                preset = selectedPreset.preset
                maxResolutionCap = selectedResolution.maxHeight
                allowHevc = binding.allowHevcCheck.isChecked
                keepAudio = binding.keepAudioCheck.isChecked
                keepOriginalIfLarger = binding.keepOriginalIfLargerCheck.isChecked
                forceCodec = selectedCodec.codec
                this.maxBitrate = maxBitrate
                this.progressIntervalMs = progressIntervalMs
            },
            listener = this,
        )
        binding.progressIndicator.progress = 0
        binding.outputValue.text = ""
        binding.statusValue.text = buildString {
            append("Compression started")
            append(" | ${selectedPreset.label}")
            append(" | ${selectedResolution.label}")
            append(" | ${selectedCodec.label}")
        }
    }

    private fun setupPickers() {
        setupSpinner(binding.resolutionSpinner, resolutionOptions.map { it.label }, 1)
        setupSpinner(binding.presetSpinner, presetOptions.map { it.label }, 1)
        setupSpinner(binding.codecSpinner, codecOptions.map { it.label }, 0)
    }

    private fun setupSpinner(
        spinner: android.widget.Spinner,
        labels: List<String>,
        defaultIndex: Int,
    ) {
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            labels,
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        spinner.adapter = adapter
        spinner.setSelection(defaultIndex)
    }

    private fun applyEdgeToEdgeInsets() {
        val horizontalPadding = resources.displayMetrics.density.times(24).toInt()
        val verticalPadding = resources.displayMetrics.density.times(24).toInt()
        ViewCompat.setOnApplyWindowInsetsListener(binding.rootScrollView) { view, windowInsets ->
            val systemBars = windowInsets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
            )
            view.updatePadding(
                left = horizontalPadding + systemBars.left,
                top = verticalPadding + systemBars.top,
                right = horizontalPadding + systemBars.right,
                bottom = verticalPadding + systemBars.bottom,
            )
            windowInsets
        }
    }

    private fun inspectVideo(uri: Uri): VideoSummary? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(this, uri)
            VideoSummary(
                width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0,
                height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0,
                sizeMb = querySizeBytes(uri).toMb(),
            )
        } catch (_: Throwable) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun querySizeBytes(uri: Uri): Long {
        if (uri.scheme == "file") {
            return File(uri.path.orEmpty()).length()
        }
        contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(android.provider.OpenableColumns.SIZE)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getLong(index)
            }
        }
        return 0L
    }
}

private object IntentFlags {
    const val readOnly = android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
}

private data class VideoSummary(
    val width: Int,
    val height: Int,
    val sizeMb: Double,
)

private data class ResolutionOption(
    val label: String,
    val maxHeight: Int?,
)

private data class PresetOption(
    val label: String,
    val preset: CompressionPreset,
)

private data class CodecOption(
    val label: String,
    val codec: ForceCodec,
)

private fun Long.toMb(): Double = this.toDouble() / (1024.0 * 1024.0)

private fun Double.formatMb(): String = String.format("%.2f", this)
