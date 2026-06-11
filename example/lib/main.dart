import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:vidsqueeze/vidsqueeze.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  runApp(const VidsqueezeExampleApp());
}

class VidsqueezeExampleApp extends StatelessWidget {
  const VidsqueezeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vidsqueeze example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF165D58),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: const CompressionDemoScreen(),
    );
  }
}

class CompressionDemoScreen extends StatefulWidget {
  const CompressionDemoScreen({super.key});

  @override
  State<CompressionDemoScreen> createState() => _CompressionDemoScreenState();
}

enum _PreviewTarget {
  original,
  compressed,
}

class _CompressionDemoScreenState extends State<CompressionDemoScreen> {
  final _plugin = Vidsqueeze.instance;
  final _maxBitrateController = TextEditingController();
  final _progressIntervalController = TextEditingController(text: '250');

  StreamSubscription<CompressionState>? _stateSubscription;

  CompressionPreset _preset = CompressionPreset.balanced;
  ForceCodec _forceCodec = ForceCodec.auto;
  CompressionResolutionCap _maxResolutionCap = CompressionResolutionCap.p1080;
  bool _allowHevc = true;
  bool _keepAudio = true;
  bool _keepOriginalIfLarger = true;

  String? _inputPath;
  String? _inputLabel;
  String? _activeTaskId;
  CompressionState? _lastState;
  CompressionResult? _lastResult;
  Object? _lastError;
  bool _isCompressing = false;
  bool _isPickingFile = false;
  bool _outputReady = false;
  VideoPlayerController? _originalVideoController;
  VideoPlayerController? _compressedVideoController;
  String? _originalPreviewError;
  String? _compressedPreviewError;
  _PreviewTarget _previewTarget = _PreviewTarget.original;
  int _originalPreviewGeneration = 0;
  int _compressedPreviewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _plugin.states().listen(_handleState);
    unawaited(_prepareOutputDirectory());
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    unawaited(_originalVideoController?.dispose());
    unawaited(_compressedVideoController?.dispose());
    _maxBitrateController.dispose();
    _progressIntervalController.dispose();
    super.dispose();
  }

  Future<void> _prepareOutputDirectory() async {
    final directory = await getTemporaryDirectory();
    final outputDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}vidsqueeze-example',
    );
    await outputDirectory.create(recursive: true);
    if (!mounted) return;
    setState(() => _outputReady = true);
  }

  Future<void> _pickVideo() async {
    setState(() {
      _isPickingFile = true;
      _lastError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      final file = result?.files.singleOrNull;
      final path = file?.path;
      if (path == null || path.isEmpty) return;

      final normalizedPath =
          path.startsWith('content://') || path.startsWith('file://')
              ? path
              : Uri.file(path).toString();

      final generation = _disposeOriginalPreview();
      _disposeCompressedPreview();
      setState(() {
        _inputPath = normalizedPath;
        _inputLabel = file?.name ?? path.split(Platform.pathSeparator).last;
        _lastResult = null;
        _lastState = null;
        _activeTaskId = null;
        _previewTarget = _PreviewTarget.original;
      });
      unawaited(_initializePreview(
        target: _PreviewTarget.original,
        source: normalizedPath,
        generation: generation,
      ));
    } catch (error) {
      setState(() => _lastError = error);
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _compress() async {
    if (_inputPath == null || !_outputReady || _isCompressing) return;

    final taskId = 'example-${DateTime.now().millisecondsSinceEpoch}';
    _disposeCompressedPreview();
    setState(() {
      _activeTaskId = taskId;
      _isCompressing = true;
      _lastResult = null;
      _lastError = null;
      _lastState = CompressionState(
        taskId: taskId,
        phase: CompressionPhase.preparing,
      );
    });

    try {
      final request = CompressionRequest(
        taskId: taskId,
        inputPath: _inputPath!,
        outputDirectoryPath: (await getTemporaryDirectory()).path,
        outputFileName: 'compressed-$taskId.mp4',
        preset: _preset,
        maxResolutionCap: _maxResolutionCap,
        allowHevc: _allowHevc,
        keepAudio: _keepAudio,
        keepOriginalIfLarger: _keepOriginalIfLarger,
        forceCodec: _forceCodec,
        maxBitrate: _parseOptionalInt(_maxBitrateController.text),
        progressIntervalMs:
            _parseRequiredInt(_progressIntervalController.text, fallback: 250),
      );

      final result = await _plugin.compress(request);
      if (!mounted) return;
      final generation = _disposeCompressedPreview();
      setState(() {
        _lastResult = result;
        _isCompressing = false;
        _previewTarget = _PreviewTarget.compressed;
      });
      unawaited(_initializePreview(
        target: _PreviewTarget.compressed,
        source: result.outputPath,
        generation: generation,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = error;
        _isCompressing = false;
      });
    }
  }

  Future<void> _cancel() async {
    final taskId = _activeTaskId;
    if (taskId == null) return;
    await _plugin.cancel(taskId);
  }

  void _handleState(CompressionState state) {
    if (_activeTaskId != null && state.taskId != _activeTaskId) return;
    if (!mounted) return;
    setState(() => _lastState = state);
  }

  int _disposeOriginalPreview() {
    _originalPreviewGeneration++;
    final controller = _originalVideoController;
    _originalVideoController = null;
    _originalPreviewError = null;
    if (controller != null) {
      unawaited(controller.pause());
      unawaited(controller.dispose());
    }
    return _originalPreviewGeneration;
  }

  int _disposeCompressedPreview() {
    _compressedPreviewGeneration++;
    final controller = _compressedVideoController;
    _compressedVideoController = null;
    _compressedPreviewError = null;
    if (controller != null) {
      unawaited(controller.pause());
      unawaited(controller.dispose());
    }
    return _compressedPreviewGeneration;
  }

  Future<void> _initializePreview({
    required _PreviewTarget target,
    required String source,
    required int generation,
  }) async {
    try {
      final controller = _createVideoController(source);
      await controller.initialize();
      if (!mounted || !_isPreviewGenerationCurrent(target, generation)) {
        await controller.dispose();
        return;
      }
      setState(() {
        _setPreviewController(target, controller);
        _setPreviewError(target, null);
      });
    } catch (error) {
      if (!mounted || !_isPreviewGenerationCurrent(target, generation)) return;
      setState(() {
        _setPreviewError(target, _formatError(error));
      });
    }
  }

  bool _isPreviewGenerationCurrent(_PreviewTarget target, int generation) {
    return switch (target) {
      _PreviewTarget.original => generation == _originalPreviewGeneration,
      _PreviewTarget.compressed => generation == _compressedPreviewGeneration,
    };
  }

  VideoPlayerController _createVideoController(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null && uri.scheme == 'content') {
      if (!Platform.isAndroid) {
        throw UnsupportedError(
            'Content URI preview is only supported on Android');
      }
      return VideoPlayerController.contentUri(uri);
    }
    if (uri != null && uri.scheme == 'file') {
      return VideoPlayerController.file(File.fromUri(uri));
    }
    return VideoPlayerController.file(File(source));
  }

  void _setPreviewTarget(_PreviewTarget target) {
    if (_previewTarget == target) return;
    unawaited(_activePreviewController?.pause());
    setState(() => _previewTarget = target);
  }

  Future<void> _togglePreviewPlayback() async {
    final controller = _activePreviewController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  VideoPlayerController? get _activePreviewController {
    return switch (_previewTarget) {
      _PreviewTarget.original => _originalVideoController,
      _PreviewTarget.compressed => _compressedVideoController,
    };
  }

  String? get _activePreviewError {
    return switch (_previewTarget) {
      _PreviewTarget.original => _originalPreviewError,
      _PreviewTarget.compressed => _compressedPreviewError,
    };
  }

  void _setPreviewController(
      _PreviewTarget target, VideoPlayerController? controller) {
    if (target == _PreviewTarget.original) {
      _originalVideoController = controller;
    } else {
      _compressedVideoController = controller;
    }
  }

  void _setPreviewError(_PreviewTarget target, String? error) {
    if (target == _PreviewTarget.original) {
      _originalPreviewError = error;
    } else {
      _compressedPreviewError = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 12),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                    bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.compress, color: cs.primary, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'vidsqueeze',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                  ),
                  const Spacer(),
                  if (_isCompressing)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: cs.primary),
                    ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
                children: [
                  // Source section
                  _SectionCard(
                    icon: Icons.videocam,
                    title: 'Source Video',
                    trailing: _inputLabel != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _inputLabel!.length > 30
                                  ? '...${_inputLabel!.substring(_inputLabel!.length - 30)}'
                                  : _inputLabel!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onTertiaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : null,
                    child: _inputPath == null
                        ? SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isPickingFile ? null : _pickVideo,
                              icon: _isPickingFile
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.folder_open),
                              label: Text(_isPickingFile
                                  ? 'Opening picker...'
                                  : 'Pick Video'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isPickingFile ? null : _pickVideo,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Change'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: _canCompress ? _compress : null,
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('Compress'),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Preview section
                  _SectionCard(
                    icon: Icons.movie,
                    title: 'Preview',
                    child: _buildPreviewSection(cs),
                  ),

                  const SizedBox(height: 12),

                  // Settings section
                  _SectionCard(
                    icon: Icons.tune,
                    title: 'Settings',
                    child: Column(
                      children: [
                        _SettingRow(
                          label: 'Preset',
                          child: _SegmentedControl<CompressionPreset>(
                            value: _preset,
                            onChanged: (v) => setState(() => _preset = v),
                            items: const {
                              CompressionPreset.quality: 'Quality',
                              CompressionPreset.balanced: 'Balanced',
                              CompressionPreset.smallSize: 'Size',
                            },
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        _SettingRow(
                          label: 'Codec',
                          child: _SegmentedControl<ForceCodec>(
                            value: _forceCodec,
                            onChanged: (v) => setState(() => _forceCodec = v),
                            items: const {
                              ForceCodec.auto: 'Auto',
                              ForceCodec.avc: 'AVC',
                              ForceCodec.hevc: 'HEVC',
                            },
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        _SettingRow(
                          label: 'Max Resolution',
                          child: _Dropdown<CompressionResolutionCap>(
                            value: _maxResolutionCap,
                            items: CompressionResolutionCap.values,
                            label: (value) => value.label,
                            onChanged: (v) =>
                                setState(() => _maxResolutionCap = v),
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        _SettingRow(
                          label: 'Max Bitrate',
                          child: SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _maxBitrateController,
                              decoration: const InputDecoration(
                                hintText: 'Auto',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Toggles section
                  _SectionCard(
                    icon: Icons.toggle_off_outlined,
                    title: 'Options',
                    child: Column(
                      children: [
                        _SwitchRow(
                          label: 'HEVC (H.265)',
                          value: _allowHevc,
                          onChanged: (v) => setState(() => _allowHevc = v),
                        ),
                        const Divider(height: 1, thickness: 1),
                        _SwitchRow(
                          label: 'Keep Audio',
                          value: _keepAudio,
                          onChanged: (v) => setState(() => _keepAudio = v),
                        ),
                        const Divider(height: 1, thickness: 1),
                        _SwitchRow(
                          label: 'Keep original if larger',
                          value: _keepOriginalIfLarger,
                          onChanged: (v) =>
                              setState(() => _keepOriginalIfLarger = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Progress section
                  _SectionCard(
                    icon: Icons.show_chart,
                    title: 'Progress',
                    child: _buildProgressSection(cs),
                  ),

                  const SizedBox(height: 12),

                  // Result section
                  _SectionCard(
                    icon: Icons.summarize,
                    title: 'Result',
                    child: _buildResultSection(cs),
                  ),

                  if (_activeTaskId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Task: $_activeTaskId',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(ColorScheme cs) {
    // Idle state — no compression running or completed
    if (!_isCompressing &&
        _lastState == null &&
        _lastResult == null &&
        _lastError == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 18, color: cs.outline),
            const SizedBox(width: 8),
            Text(
              'Select a video and tap Compress to begin',
              style: TextStyle(color: cs.outline, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase badge
        Row(
          children: [
            _PhaseBadge(phase: _lastState?.phase),
            if (_isCompressing || _lastState != null) ...[
              const Spacer(),
              Text(
                '${_lastState?.progressPercent ?? 0}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            value: _progressValue,
          ),
        ),
        const SizedBox(height: 6),
        if (_lastState?.message case final msg?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              msg,
              style: TextStyle(
                  color: cs.outline, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        if (_isCompressing) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Cancel task'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewSection(ColorScheme cs) {
    final controller = _activePreviewController;
    final error = _activePreviewError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _SegmentedControl<_PreviewTarget>(
            value: _previewTarget,
            onChanged: _setPreviewTarget,
            items: const {
              _PreviewTarget.original: 'Original',
              _PreviewTarget.compressed: 'Compressed',
            },
          ),
        ),
        const SizedBox(height: 12),
        if (controller != null && controller.value.isInitialized)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else
          _PreviewPlaceholder(
            message: error ?? _previewEmptyMessage,
            isError: error != null,
          ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: controller != null && controller.value.isInitialized
              ? _togglePreviewPlayback
              : null,
          icon: Icon(controller?.value.isPlaying == true
              ? Icons.pause
              : Icons.play_arrow),
          label: Text(controller?.value.isPlaying == true ? 'Pause' : 'Play'),
        ),
      ],
    );
  }

  String get _previewEmptyMessage {
    if (_previewTarget == _PreviewTarget.compressed && _lastResult == null) {
      return 'Compress a video to preview output';
    }
    if (_previewTarget == _PreviewTarget.original && _inputPath == null) {
      return 'Pick a video to preview it here';
    }
    return 'Preparing preview...';
  }

  double? get _progressValue {
    final phase = _lastState?.phase;
    if (phase == null) return null;
    if (phase == CompressionPhase.completed ||
        phase == CompressionPhase.failed) {
      return null;
    }
    if (phase == CompressionPhase.transcoding) {
      final pct = _lastState!.progressPercent;
      if (pct == null) return null;
      return (pct / 100.0).clamp(0.0, 1.0);
    }
    return null;
  }

  Widget _buildResultSection(ColorScheme cs) {
    if (_lastError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formatError(_lastError),
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_lastResult == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 18, color: cs.outline),
            const SizedBox(width: 8),
            Text(
              'No compression result yet',
              style: TextStyle(color: cs.outline, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final r = _lastResult!;
    final savedBytes = r.sourceSizeBytes - r.outputSizeBytes;
    final savedPct = r.sourceSizeBytes > 0
        ? ((savedBytes / r.sourceSizeBytes) * 100).toStringAsFixed(1)
        : '0.0';

    return Column(
      children: [
        _ResultRow(label: 'Codec', value: r.codec.value),
        _ResultRow(
            label: 'Resolution',
            value: r.targetHeight != null ? '${r.targetHeight}p' : 'Original'),
        _ResultRow(label: 'Bitrate', value: _formatBitrate(r.targetBitrate)),
        _ResultRow(label: 'Duration', value: '${r.durationMs} ms'),
        const Divider(height: 16),
        _ResultRow(label: 'Source size', value: _formatMb(r.sourceSizeBytes)),
        _ResultRow(label: 'Output size', value: _formatMb(r.outputSizeBytes)),
        _ResultRow(
          label: 'Saved',
          value: '$savedPct% (${_formatMb(savedBytes)})',
          valueColor: savedPct.startsWith('-') ? cs.error : cs.primary,
        ),
        const Divider(height: 16),
        _ResultRow(label: 'Attempts', value: '${r.attempts}'),
        _ResultRow(
          label: 'Used original',
          value: r.usedOriginalSource ? 'Yes' : 'No',
        ),
      ],
    );
  }

  bool get _canCompress {
    return !_isPickingFile &&
        !_isCompressing &&
        _inputPath != null &&
        _outputReady;
  }
}

// Widget Helpers

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: child),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 124,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.onChanged,
    required this.items,
    this.adaptive = true,
  });
  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, String> items;
  final bool adaptive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final shouldUseDropdown =
            adaptive && _shouldUseDropdown(availableWidth);

        if (shouldUseDropdown) {
          return _Dropdown<T>(
            value: value,
            items: items.keys.toList(growable: false),
            label: (item) => items[item]!,
            onChanged: onChanged,
          );
        }

        return SegmentedButton<T>(
          segments: items.entries
              .map(
                (e) => ButtonSegment(
                  value: e.key,
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        );
      },
    );
  }

  bool _shouldUseDropdown(double availableWidth) {
    final longestLabel = items.values.fold<int>(
      0,
      (max, label) => label.length > max ? label.length : max,
    );
    final estimatedWidth = (items.length * 72) + (longestLabel * 6);
    return availableWidth < estimatedWidth;
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown(
      {required this.value,
      required this.items,
      required this.label,
      required this.onChanged});
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        items: items
            .map((e) => DropdownMenuItem(
                value: e,
                child: Text(label(e), style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase});
  final CompressionPhase? phase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg, String text) = switch (phase) {
      null => (cs.surfaceContainerHighest, cs.outline, 'Idle'),
      CompressionPhase.preparing => (
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
          'Preparing'
        ),
      CompressionPhase.transcoding => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          'Transcoding'
        ),
      CompressionPhase.finalizing => (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          'Finalizing'
        ),
      CompressionPhase.completed => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          'Completed'
        ),
      CompressionPhase.failed => (
          cs.errorContainer,
          cs.onErrorContainer,
          'Failed'
        ),
      CompressionPhase.cancelled => (
          cs.errorContainer,
          cs.onErrorContainer,
          'Cancelled'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isError ? cs.error : cs.outline;
    final bg = isError
        ? cs.errorContainer.withValues(alpha: 0.35)
        : cs.surfaceContainerHighest;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isError ? Icons.error_outline : Icons.movie_outlined,
              color: color),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// Utility Helpers

int? _parseOptionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

int _parseRequiredInt(String value, {required int fallback}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return fallback;
  return int.tryParse(trimmed) ?? fallback;
}

String _formatMb(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(2)} MB';
}

String _formatBitrate(int? bitrate) {
  if (bitrate == null) return 'Auto';
  if (bitrate >= 1000000) {
    return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
  }
  return '${(bitrate / 1000).toStringAsFixed(0)} Kbps';
}

String _formatError(Object? error) {
  final s = error.toString();
  if (s.contains('Exception:')) return s.split('Exception:').last.trim();
  if (s.contains(':')) return s.split(':').last.trim();
  return s;
}
