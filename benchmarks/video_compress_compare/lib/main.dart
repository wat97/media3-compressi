import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart' as video_compress;
import 'package:vidsqueeze/vidsqueeze.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vidsqueeze benchmark',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.12),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const BenchmarkScreen(),
    );
  }
}

enum BenchmarkEngine {
  vidsqueeze,
  videoCompress;

  String get label {
    return switch (this) {
      BenchmarkEngine.vidsqueeze => 'vidsqueeze',
      BenchmarkEngine.videoCompress => 'video_compress',
    };
  }
}

class BenchmarkScenario {
  const BenchmarkScenario({
    required this.id,
    required this.label,
    required this.vidsqueezePreset,
    required this.includeAudio,
  });

  final String id;
  final String label;
  final CompressionPreset vidsqueezePreset;
  final bool includeAudio;
}

class BenchmarkResolution {
  const BenchmarkResolution({
    required this.label,
    required this.vidsqueezeCap,
    required this.videoCompressQuality,
  });

  final String label;
  final int? vidsqueezeCap;
  final video_compress.VideoQuality videoCompressQuality;
}

class BenchmarkResult {
  const BenchmarkResult({
    required this.engine,
    required this.scenario,
    required this.resolution,
    required this.runNumber,
    required this.elapsedMs,
    required this.sourceSizeBytes,
    required this.outputSizeBytes,
    this.outputPath,
    this.width,
    this.height,
    this.mediaDurationMs,
    this.progressPercent,
    this.note,
    this.error,
  });

  final BenchmarkEngine engine;
  final BenchmarkScenario scenario;
  final BenchmarkResolution resolution;
  final int runNumber;
  final int elapsedMs;
  final int sourceSizeBytes;
  final int outputSizeBytes;
  final String? outputPath;
  final int? width;
  final int? height;
  final int? mediaDurationMs;
  final int? progressPercent;
  final String? note;
  final String? error;

  bool get isSuccess => error == null;

  double get savedPercent {
    if (sourceSizeBytes <= 0) return 0;
    return ((sourceSizeBytes - outputSizeBytes) / sourceSizeBytes) * 100;
  }
}

class _VideoCompressAttempt {
  const _VideoCompressAttempt({
    required this.quality,
    required this.mediaInfo,
    required this.usedFallback,
  });

  final video_compress.VideoQuality quality;
  final video_compress.MediaInfo mediaInfo;
  final bool usedFallback;
}

const _scenarios = <BenchmarkScenario>[
  BenchmarkScenario(
    id: 'quality',
    label: 'Quality',
    vidsqueezePreset: CompressionPreset.quality,
    includeAudio: true,
  ),
  BenchmarkScenario(
    id: 'balanced',
    label: 'Balanced',
    vidsqueezePreset: CompressionPreset.balanced,
    includeAudio: true,
  ),
  BenchmarkScenario(
    id: 'small',
    label: 'Small',
    vidsqueezePreset: CompressionPreset.smallSize,
    includeAudio: true,
  ),
];

const _resolutions = <BenchmarkResolution>[
  BenchmarkResolution(
    label: 'Original',
    vidsqueezeCap: null,
    videoCompressQuality: video_compress.VideoQuality.HighestQuality,
  ),
  BenchmarkResolution(
    label: '1080p',
    vidsqueezeCap: 1080,
    videoCompressQuality: video_compress.VideoQuality.Res1920x1080Quality,
  ),
  BenchmarkResolution(
    label: '720p',
    vidsqueezeCap: 720,
    videoCompressQuality: video_compress.VideoQuality.Res1280x720Quality,
  ),
  BenchmarkResolution(
    label: '540p',
    vidsqueezeCap: 540,
    videoCompressQuality: video_compress.VideoQuality.Res960x540Quality,
  ),
  BenchmarkResolution(
    label: '480p',
    vidsqueezeCap: 480,
    videoCompressQuality: video_compress.VideoQuality.Res640x480Quality,
  ),
];

const _engineCooldown = Duration(seconds: 10);
const _deviceSampleFileName = 'vidsqueeze-benchmark-input.mp4';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final _vidsqueeze = Vidsqueeze.instance;
  final _runsController = TextEditingController(text: '1');
  final _results = <BenchmarkResult>[];

  StreamSubscription<CompressionState>? _vidsqueezeStates;
  video_compress.Subscription? _videoCompressProgress;

  String? _inputPath;
  String? _inputLabel;
  int? _sourceSizeBytes;
  int _scenarioIndex = 1;
  int _resolutionIndex = 1;
  bool _running = false;
  bool _picking = false;
  bool _runBothEngines = true;
  bool _forceVidsqueezeAvc = true;
  String? _status;
  int? _activeProgress;

  BenchmarkScenario get _scenario => _scenarios[_scenarioIndex];
  BenchmarkResolution get _resolution => _resolutions[_resolutionIndex];

  @override
  void initState() {
    super.initState();
    _vidsqueezeStates = _vidsqueeze.states().listen((state) {
      if (state.progressPercent == null) return;
      if (!mounted) return;
      setState(() => _activeProgress = state.progressPercent);
    });
    unawaited(_loadDeviceSampleIfPresent());
  }

  @override
  void dispose() {
    _vidsqueezeStates?.cancel();
    _videoCompressProgress?.unsubscribe();
    _runsController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_running) return;
    setState(() {
      _picking = true;
      _status = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.video);
      final file = picked?.files.singleOrNull;
      final path = file?.path;
      if (path == null || path.isEmpty) return;

      final size = await File(path).length();
      if (!mounted) return;
      setState(() {
        _inputPath = path;
        _inputLabel = file?.name ?? path.split(Platform.pathSeparator).last;
        _sourceSizeBytes = size;
        _results.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _formatError(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _loadDeviceSampleIfPresent() async {
    if (!Platform.isAndroid) return;
    final directory = await getExternalStorageDirectory();
    if (directory == null) return;
    final sample = File(
      '${directory.path}${Platform.pathSeparator}$_deviceSampleFileName',
    );
    if (!await sample.exists()) return;

    final size = await sample.length();
    if (!mounted || _inputPath != null) return;
    setState(() {
      _inputPath = sample.path;
      _inputLabel = _deviceSampleFileName;
      _sourceSizeBytes = size;
      _status = 'Loaded device sample';
      _results.clear();
    });
  }

  Future<void> _runBenchmark() async {
    final inputPath = _inputPath;
    if (inputPath == null || _running) return;

    final runCount = _parseRunCount();

    setState(() {
      _running = true;
      _status = 'Starting benchmark';
      _activeProgress = null;
      _results.clear();
    });

    try {
      final sourceSize = await File(inputPath).length();
      for (var run = 1; run <= runCount; run++) {
        if (_runBothEngines) {
          final videoCompressResult = await _runEngineWithStatus(
            engine: BenchmarkEngine.videoCompress,
            scenario: _scenario,
            resolution: _resolution,
            inputPath: inputPath,
            sourceSizeBytes: sourceSize,
            runNumber: run,
            runCount: runCount,
          );
          if (!mounted) return;
          setState(() => _results.add(videoCompressResult));

          await _waitBeforeVidsqueeze(run: run, runCount: runCount);
          if (!mounted) return;

          final vidsqueezeResult = await _runEngineWithStatus(
            engine: BenchmarkEngine.vidsqueeze,
            scenario: _scenario,
            resolution: _resolution,
            inputPath: inputPath,
            sourceSizeBytes: sourceSize,
            runNumber: run,
            runCount: runCount,
          );
          if (!mounted) return;
          setState(() => _results.add(vidsqueezeResult));
        } else {
          final result = await _runEngineWithStatus(
            engine: BenchmarkEngine.vidsqueeze,
            scenario: _scenario,
            resolution: _resolution,
            inputPath: inputPath,
            sourceSizeBytes: sourceSize,
            runNumber: run,
            runCount: runCount,
          );
          if (!mounted) return;
          setState(() => _results.add(result));
        }
      }
      if (!mounted) return;
      setState(() => _status = 'Benchmark complete');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _activeProgress = null;
        });
      }
    }
  }

  Future<BenchmarkResult> _runEngineWithStatus({
    required BenchmarkEngine engine,
    required BenchmarkScenario scenario,
    required BenchmarkResolution resolution,
    required String inputPath,
    required int sourceSizeBytes,
    required int runNumber,
    required int runCount,
  }) async {
    setState(() {
      _status =
          'Run $runNumber/$runCount: ${engine.label} ${scenario.label} ${resolution.label}';
      _activeProgress = null;
    });

    return _runSingle(
      engine: engine,
      scenario: scenario,
      resolution: resolution,
      inputPath: inputPath,
      sourceSizeBytes: sourceSizeBytes,
      runNumber: runNumber,
    );
  }

  Future<void> _waitBeforeVidsqueeze({
    required int run,
    required int runCount,
  }) async {
    for (var remaining = _engineCooldown.inSeconds;
        remaining > 0;
        remaining--) {
      if (!_running || !mounted) return;
      setState(() {
        _status =
            'Run $run/$runCount: video_compress done. Waiting ${remaining}s before vidsqueeze';
        _activeProgress = null;
      });
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<BenchmarkResult> _runSingle({
    required BenchmarkEngine engine,
    required BenchmarkScenario scenario,
    required BenchmarkResolution resolution,
    required String inputPath,
    required int sourceSizeBytes,
    required int runNumber,
  }) async {
    return switch (engine) {
      BenchmarkEngine.vidsqueeze => _runVidsqueeze(
          scenario: scenario,
          resolution: resolution,
          inputPath: inputPath,
          sourceSizeBytes: sourceSizeBytes,
          runNumber: runNumber,
        ),
      BenchmarkEngine.videoCompress => _runVideoCompress(
          scenario: scenario,
          resolution: resolution,
          inputPath: inputPath,
          sourceSizeBytes: sourceSizeBytes,
          runNumber: runNumber,
        ),
    };
  }

  Future<BenchmarkResult> _runVidsqueeze({
    required BenchmarkScenario scenario,
    required BenchmarkResolution resolution,
    required String inputPath,
    required int sourceSizeBytes,
    required int runNumber,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final outputDirectory = await _benchmarkOutputDirectory();
      final taskId =
          'bench-${scenario.id}-$runNumber-${DateTime.now().millisecondsSinceEpoch}';
      final result = await _vidsqueeze.compress(CompressionRequest(
        taskId: taskId,
        inputPath: Uri.file(inputPath).toString(),
        outputDirectoryPath: outputDirectory.path,
        outputFileName: '$taskId.mp4',
        preset: scenario.vidsqueezePreset,
        maxResolutionCap: resolution.vidsqueezeCap,
        allowHevc: !_forceVidsqueezeAvc,
        keepAudio: scenario.includeAudio,
        keepOriginalIfLarger: false,
        forceCodec: _forceVidsqueezeAvc ? ForceCodec.avc : ForceCodec.auto,
        progressIntervalMs: 250,
      ));
      stopwatch.stop();

      return BenchmarkResult(
        engine: BenchmarkEngine.vidsqueeze,
        scenario: scenario,
        resolution: resolution,
        runNumber: runNumber,
        elapsedMs: stopwatch.elapsedMilliseconds,
        sourceSizeBytes: sourceSizeBytes,
        outputSizeBytes: result.outputSizeBytes,
        outputPath: result.outputPath,
        height: result.targetHeight,
        mediaDurationMs: result.durationMs,
      );
    } catch (error) {
      stopwatch.stop();
      return BenchmarkResult(
        engine: BenchmarkEngine.vidsqueeze,
        scenario: scenario,
        resolution: resolution,
        runNumber: runNumber,
        elapsedMs: stopwatch.elapsedMilliseconds,
        sourceSizeBytes: sourceSizeBytes,
        outputSizeBytes: 0,
        error: _formatError(error),
      );
    }
  }

  Future<BenchmarkResult> _runVideoCompress({
    required BenchmarkScenario scenario,
    required BenchmarkResolution resolution,
    required String inputPath,
    required int sourceSizeBytes,
    required int runNumber,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final fallbackQualities =
          _videoCompressFallbackQualities(resolution.videoCompressQuality);
      _videoCompressProgress?.unsubscribe();
      _videoCompressProgress =
          video_compress.VideoCompress.compressProgress$.subscribe((progress) {
        if (!mounted) return;
        setState(() => _activeProgress = progress.round().clamp(0, 100));
      });

      final attempt = await _compressWithVideoCompressFallback(
        inputPath: inputPath,
        qualities: fallbackQualities,
        includeAudio: scenario.includeAudio,
      );
      stopwatch.stop();

      if (attempt == null) {
        return BenchmarkResult(
          engine: BenchmarkEngine.videoCompress,
          scenario: scenario,
          resolution: resolution,
          runNumber: runNumber,
          elapsedMs: stopwatch.elapsedMilliseconds,
          sourceSizeBytes: sourceSizeBytes,
          outputSizeBytes: 0,
          error:
              'FAILED after retries: ${fallbackQualities.map((q) => q.name).join(' -> ')} returned null',
        );
      }

      final mediaInfo = attempt.mediaInfo;
      final outputPath = mediaInfo.path;
      final outputSize = mediaInfo.filesize ??
          (outputPath == null ? 0 : await File(outputPath).length());

      return BenchmarkResult(
        engine: BenchmarkEngine.videoCompress,
        scenario: scenario,
        resolution: resolution,
        runNumber: runNumber,
        elapsedMs: stopwatch.elapsedMilliseconds,
        sourceSizeBytes: sourceSizeBytes,
        outputSizeBytes: outputSize,
        outputPath: outputPath,
        width: mediaInfo.width,
        height: mediaInfo.height,
        mediaDurationMs: mediaInfo.duration?.round(),
        note: attempt.usedFallback
            ? 'fallback quality: ${attempt.quality.name}'
            : null,
      );
    } catch (error) {
      stopwatch.stop();
      return BenchmarkResult(
        engine: BenchmarkEngine.videoCompress,
        scenario: scenario,
        resolution: resolution,
        runNumber: runNumber,
        elapsedMs: stopwatch.elapsedMilliseconds,
        sourceSizeBytes: sourceSizeBytes,
        outputSizeBytes: 0,
        error: _formatError(error),
      );
    }
  }

  Future<_VideoCompressAttempt?> _compressWithVideoCompressFallback({
    required String inputPath,
    required List<video_compress.VideoQuality> qualities,
    required bool includeAudio,
  }) async {
    final requestedQuality = qualities.first;

    for (final quality in qualities) {
      if (!mounted || !_running) return null;
      setState(() {
        _status = 'video_compress attempt: ${quality.name}';
        _activeProgress = null;
      });
      await video_compress.VideoCompress.deleteAllCache();
      final mediaInfo = await video_compress.VideoCompress.compressVideo(
        inputPath,
        quality: quality,
        deleteOrigin: false,
        includeAudio: includeAudio,
      );
      if (mediaInfo != null) {
        return _VideoCompressAttempt(
          quality: quality,
          mediaInfo: mediaInfo,
          usedFallback: quality != requestedQuality,
        );
      }
      if (quality != qualities.last) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    return null;
  }

  List<video_compress.VideoQuality> _videoCompressFallbackQualities(
    video_compress.VideoQuality requestedQuality,
  ) {
    final qualities = <video_compress.VideoQuality>[
      requestedQuality,
      video_compress.VideoQuality.DefaultQuality,
      video_compress.VideoQuality.MediumQuality,
      video_compress.VideoQuality.LowQuality,
    ];
    return qualities.toSet().toList();
  }

  Future<void> _cancelActive() async {
    await video_compress.VideoCompress.cancelCompression();
    setState(() {
      _running = false;
      _status = 'Cancel requested';
      _activeProgress = null;
    });
  }

  Future<Directory> _benchmarkOutputDirectory() async {
    final temp = await getTemporaryDirectory();
    final directory = Directory(
      '${temp.path}${Platform.pathSeparator}vidsqueeze-benchmark',
    );
    await directory.create(recursive: true);
    return directory;
  }

  int _parseRunCount() {
    final parsed = int.tryParse(_runsController.text.trim()) ?? 1;
    return parsed.clamp(1, 5);
  }

  void _openResultsPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BenchmarkResultsPage(
          inputLabel: _inputLabel,
          sourceSizeBytes: _sourceSizeBytes,
          results: List.unmodifiable(_results),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Benchmark'),
        centerTitle: false,
        toolbarHeight: 52,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding + 12),
        children: [
          _Panel(
            title: 'Input',
            icon: Icons.video_file_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _picking || _running ? null : _pickVideo,
                  icon: _picking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label:
                      Text(_inputLabel == null ? 'Pick video' : 'Change video'),
                ),
                if (_inputLabel != null) ...[
                  const SizedBox(height: 10),
                  _MetricRow('File', _inputLabel!),
                  _MetricRow('Source size', _formatMb(_sourceSizeBytes ?? 0)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Panel(
            title: 'Scenario',
            icon: Icons.tune,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Quality')),
                    ButtonSegment(value: 1, label: Text('Balanced')),
                    ButtonSegment(value: 2, label: Text('Small')),
                  ],
                  selected: {_scenarioIndex},
                  onSelectionChanged: _running
                      ? null
                      : (selected) =>
                          setState(() => _scenarioIndex = selected.single),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _resolutionIndex,
                  decoration: const InputDecoration(
                    labelText: 'Resolution',
                    isDense: true,
                  ),
                  items: [
                    for (var i = 0; i < _resolutions.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(_resolutions[i].label),
                      ),
                  ],
                  onChanged: _running
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _resolutionIndex = value);
                        },
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  'vidsqueeze',
                  _vidsqueezeScenarioLabel(_scenario, _resolution),
                ),
                _MetricRow(
                  'video_compress',
                  _videoCompressScenarioLabel(_resolution),
                ),
                _MetricRow(
                    'Order',
                    _runBothEngines
                        ? 'video_compress -> 10s wait -> vidsqueeze'
                        : 'vidsqueeze only'),
                const Divider(height: 20),
                _CompactSwitch(
                  title: 'Run both engines',
                  subtitle: 'Disable to run vidsqueeze only',
                  value: _runBothEngines,
                  onChanged: _running
                      ? null
                      : (value) => setState(() => _runBothEngines = value),
                ),
                _CompactSwitch(
                  title: 'Force vidsqueeze AVC',
                  subtitle: 'AVC-to-AVC comparison',
                  value: _forceVidsqueezeAvc,
                  onChanged: _running
                      ? null
                      : (value) => setState(() => _forceVidsqueezeAvc = value),
                ),
                Row(
                  children: [
                    const Text('Runs'),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: _runsController,
                        enabled: !_running,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '1-5',
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_running)
                      OutlinedButton.icon(
                        onPressed: _cancelActive,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Cancel'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _inputPath == null ? null : _runBenchmark,
                        icon: const Icon(Icons.speed),
                        label: const Text('Run'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Panel(
            title: 'Progress',
            icon: Icons.show_chart,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_status ?? 'Pick video and run benchmark'),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _running && _activeProgress == null
                      ? null
                      : (_activeProgress ?? 0) / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                if (_activeProgress != null) ...[
                  const SizedBox(height: 8),
                  Text('$_activeProgress%'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Panel(
            title: 'Results',
            icon: Icons.table_chart_outlined,
            child: _results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No benchmark results yet.'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricRow('Rows', '${_results.length}'),
                      _MetricRow('Runs', '${_completedRunCount(_results)}'),
                      _MetricRow('Success',
                          '${_successCount(_results)} / ${_results.length}'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _openResultsPage,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open result details'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class BenchmarkResultsPage extends StatelessWidget {
  const BenchmarkResultsPage({
    super.key,
    required this.inputLabel,
    required this.sourceSizeBytes,
    required this.results,
  });

  final String? inputLabel;
  final int? sourceSizeBytes;
  final List<BenchmarkResult> results;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final runs = _completedRuns(results);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Details'),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding + 12),
        children: [
          _Panel(
            title: 'Source',
            icon: Icons.video_file_outlined,
            child: Column(
              children: [
                _MetricRow('File', inputLabel ?? '-'),
                _MetricRow('Source size', _formatMb(sourceSizeBytes ?? 0)),
                _MetricRow('Rows', '${results.length}'),
                _MetricRow(
                    'Success', '${_successCount(results)} / ${results.length}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Panel(
            title: 'Comparison',
            icon: Icons.compare_arrows,
            child: runs.isEmpty
                ? const Text('No completed runs yet.')
                : Column(
                    children: [
                      for (final run in runs) ...[
                        _ComparisonCard(runNumber: run, results: results),
                        if (run != runs.last) const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          _Panel(
            title: 'Raw Results',
            icon: Icons.table_chart_outlined,
            child: _ResultsList(results: results),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.runNumber,
    required this.results,
  });

  final int runNumber;
  final List<BenchmarkResult> results;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final videoCompress = _findResult(
      results,
      runNumber,
      BenchmarkEngine.videoCompress,
    );
    final vidsqueeze = _findResult(
      results,
      runNumber,
      BenchmarkEngine.vidsqueeze,
    );
    final scenario = vidsqueeze?.scenario ?? videoCompress?.scenario;
    final resolution = vidsqueeze?.resolution ?? videoCompress?.resolution;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Run #$runNumber ${scenario?.label ?? ''} ${resolution?.label ?? ''}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            _MetricRow('Size winner', _sizeWinner(videoCompress, vidsqueeze)),
            _MetricRow('Time winner', _timeWinner(videoCompress, vidsqueeze)),
            _MetricRow('Output delta', _outputDelta(videoCompress, vidsqueeze)),
            const Divider(height: 18),
            _MetricRow('video_compress', _resultSummary(videoCompress)),
            _MetricRow('vidsqueeze', _resultSummary(vidsqueeze)),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final List<BenchmarkResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const Text('No raw result rows yet.');

    return Column(
      children: [
        for (var i = 0; i < results.length; i++) ...[
          _ResultDetailCard(result: results[i]),
          if (i != results.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ResultDetailCard extends StatelessWidget {
  const _ResultDetailCard({required this.result});

  final BenchmarkResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: result.isSuccess
            ? cs.primaryContainer.withValues(alpha: 0.20)
            : cs.errorContainer.withValues(alpha: 0.28),
        border: Border.all(
          color: result.isSuccess ? cs.outlineVariant : cs.error,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  result.isSuccess
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: result.isSuccess ? cs.primary : cs.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${result.engine.label} #${result.runNumber}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _StatusPill(isSuccess: result.isSuccess),
              ],
            ),
            const SizedBox(height: 10),
            _MetricRow(
              'Scenario',
              '${result.scenario.label} ${result.resolution.label}',
            ),
            _MetricRow('Elapsed', _formatDuration(result.elapsedMs)),
            _MetricRow('Source', _formatMb(result.sourceSizeBytes)),
            _MetricRow(
              'Output',
              result.isSuccess ? _formatMb(result.outputSizeBytes) : '-',
            ),
            _MetricRow(
              'Saved',
              result.isSuccess
                  ? '${result.savedPercent.toStringAsFixed(1)}%'
                  : '-',
            ),
            _MetricRow('Resolution', _resolution(result)),
            if (result.mediaDurationMs != null)
              _MetricRow('Duration', _formatDuration(result.mediaDurationMs!)),
            if (result.progressPercent != null)
              _MetricRow('Progress', '${result.progressPercent}%'),
            if (result.note != null) _MetricRow('Note', result.note!),
            if (result.outputPath != null)
              _DetailBlock(
                label: 'Output path',
                value: result.outputPath!,
              ),
            if (result.error != null)
              _DetailBlock(
                label: 'Error',
                value: result.error!,
                color: cs.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isSuccess});

  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isSuccess ? cs.primary : cs.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          isSuccess ? 'OK' : 'FAILED',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

int _successCount(List<BenchmarkResult> results) {
  return results.where((result) => result.isSuccess).length;
}

int _completedRunCount(List<BenchmarkResult> results) {
  return _completedRuns(results).length;
}

List<int> _completedRuns(List<BenchmarkResult> results) {
  final runs = results.map((result) => result.runNumber).toSet().toList();
  runs.sort();
  return runs;
}

BenchmarkResult? _findResult(
  List<BenchmarkResult> results,
  int runNumber,
  BenchmarkEngine engine,
) {
  for (final result in results) {
    if (result.runNumber == runNumber && result.engine == engine) {
      return result;
    }
  }
  return null;
}

String _sizeWinner(
    BenchmarkResult? videoCompress, BenchmarkResult? vidsqueeze) {
  if (videoCompress?.isSuccess != true && vidsqueeze?.isSuccess != true) {
    return 'No successful output';
  }
  if (videoCompress?.isSuccess != true) return 'vidsqueeze only succeeded';
  if (vidsqueeze?.isSuccess != true) return 'video_compress only succeeded';

  final vcBytes = videoCompress!.outputSizeBytes;
  final vsBytes = vidsqueeze!.outputSizeBytes;
  if (vcBytes == vsBytes) return 'Tie';
  return vcBytes < vsBytes ? 'video_compress smaller' : 'vidsqueeze smaller';
}

String _timeWinner(
    BenchmarkResult? videoCompress, BenchmarkResult? vidsqueeze) {
  if (videoCompress?.isSuccess != true && vidsqueeze?.isSuccess != true) {
    return 'No successful output';
  }
  if (videoCompress?.isSuccess != true) return 'vidsqueeze only succeeded';
  if (vidsqueeze?.isSuccess != true) return 'video_compress only succeeded';

  final vcMs = videoCompress!.elapsedMs;
  final vsMs = vidsqueeze!.elapsedMs;
  if (vcMs == vsMs) return 'Tie';
  return vcMs < vsMs ? 'video_compress faster' : 'vidsqueeze faster';
}

String _outputDelta(
    BenchmarkResult? videoCompress, BenchmarkResult? vidsqueeze) {
  if (videoCompress?.isSuccess != true || vidsqueeze?.isSuccess != true) {
    return '-';
  }

  final delta = vidsqueeze!.outputSizeBytes - videoCompress!.outputSizeBytes;
  if (delta == 0) return 'Same output size';

  final absDelta = delta.abs();
  final baseline = videoCompress.outputSizeBytes;
  final percent = baseline <= 0 ? 0 : (absDelta / baseline) * 100;
  final direction = delta < 0 ? 'smaller' : 'larger';
  return 'vidsqueeze ${_formatMb(absDelta)} $direction (${percent.toStringAsFixed(1)}%)';
}

String _resultSummary(BenchmarkResult? result) {
  if (result == null) return 'Not run';
  if (!result.isSuccess) return result.error ?? 'Failed';
  final note = result.note == null ? '' : ', ${result.note}';
  return '${_formatDuration(result.elapsedMs)}, ${_formatMb(result.outputSizeBytes)}, saved ${result.savedPercent.toStringAsFixed(1)}%, ${_resolution(result)}$note';
}

String _vidsqueezeScenarioLabel(
  BenchmarkScenario scenario,
  BenchmarkResolution resolution,
) {
  final height = resolution.vidsqueezeCap == null
      ? 'original'
      : '${resolution.vidsqueezeCap}p';
  return '${scenario.vidsqueezePreset.value}, $height, audio ${scenario.includeAudio ? 'on' : 'off'}';
}

String _videoCompressScenarioLabel(BenchmarkResolution resolution) {
  return '${resolution.videoCompressQuality.name} (${resolution.label})';
}

String _resolution(BenchmarkResult result) {
  if (result.width != null && result.height != null) {
    return '${result.width}x${result.height}';
  }
  if (result.height != null) return '${result.height}p';
  return '-';
}

String _formatDuration(int millis) {
  if (millis < 1000) return '${millis}ms';
  return '${(millis / 1000).toStringAsFixed(2)}s';
}

String _formatMb(int bytes) {
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String _formatError(Object error) {
  if (error is PlatformException) {
    return '${error.code}: ${error.message ?? error.details ?? ''}'.trim();
  }
  return error.toString();
}
