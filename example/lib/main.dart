import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidsqueeze/vidsqueeze.dart';

void main() {
  runApp(const VidsqueezeExampleApp());
}

class VidsqueezeExampleApp extends StatelessWidget {
  const VidsqueezeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vidsqueeze example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF165D58)),
        useMaterial3: true,
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

class _CompressionDemoScreenState extends State<CompressionDemoScreen> {
  final _plugin = Vidsqueeze.instance;
  final _maxBitrateController = TextEditingController();
  final _progressIntervalController = TextEditingController(text: '250');

  StreamSubscription<CompressionState>? _stateSubscription;

  CompressionPreset _preset = CompressionPreset.balanced;
  ForceCodec _forceCodec = ForceCodec.auto;
  int? _maxResolutionCap = 1080;
  bool _allowHevc = true;
  bool _keepAudio = true;
  bool _keepOriginalIfLarger = true;

  String? _inputPath;
  String? _inputLabel;
  String? _outputDirectoryPath;
  String? _activeTaskId;
  CompressionState? _lastState;
  CompressionResult? _lastResult;
  Object? _lastError;
  bool _isCompressing = false;
  bool _isPickingFile = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _plugin.states().listen(_handleState);
    unawaited(_prepareOutputDirectory());
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
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
    if (!mounted) {
      return;
    }
    setState(() {
      _outputDirectoryPath = outputDirectory.path;
    });
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
      if (path == null || path.isEmpty) {
        return;
      }

      final normalizedPath = path.startsWith('content://') || path.startsWith('file://')
          ? path
          : Uri.file(path).toString();

      setState(() {
        _inputPath = normalizedPath;
        _inputLabel = file?.name ?? path.split(Platform.pathSeparator).last;
        _lastResult = null;
        _lastState = null;
        _activeTaskId = null;
      });
    } catch (error) {
      setState(() {
        _lastError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _compress() async {
    if (_inputPath == null || _outputDirectoryPath == null || _isCompressing) {
      return;
    }

    final taskId = 'example-${DateTime.now().millisecondsSinceEpoch}';
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
        outputDirectoryPath: _outputDirectoryPath!,
        outputFileName: 'compressed-$taskId.mp4',
        preset: _preset,
        maxResolutionCap: _maxResolutionCap,
        allowHevc: _allowHevc,
        keepAudio: _keepAudio,
        keepOriginalIfLarger: _keepOriginalIfLarger,
        forceCodec: _forceCodec,
        maxBitrate: _parseOptionalInt(_maxBitrateController.text),
        progressIntervalMs: _parseRequiredInt(_progressIntervalController.text, fallback: 250),
      );

      final result = await _plugin.compress(request);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastResult = result;
        _isCompressing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastError = error;
        _isCompressing = false;
      });
    }
  }

  Future<void> _cancel() async {
    final taskId = _activeTaskId;
    if (taskId == null) {
      return;
    }
    await _plugin.cancel(taskId);
  }

  void _handleState(CompressionState state) {
    if (_activeTaskId != null && state.taskId != _activeTaskId) {
      return;
    }

    setState(() {
      _lastState = state;
      if (state.phase == CompressionPhase.failed || state.phase == CompressionPhase.cancelled) {
        _isCompressing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('vidsqueeze example'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionCard(
            title: 'Source',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: _isPickingFile || _isCompressing ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(_isPickingFile ? 'Picking video...' : 'Pick video'),
                ),
                const SizedBox(height: 12),
                Text(_inputLabel ?? 'No video selected'),
                const SizedBox(height: 8),
                SelectableText(
                  _inputPath ?? 'Input path will appear here',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text('Output directory', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(
                  _outputDirectoryPath ?? 'Preparing temp directory...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Request',
            child: Column(
              children: [
                DropdownButtonFormField<CompressionPreset>(
                  value: _preset,
                  decoration: const InputDecoration(labelText: 'Preset'),
                  items: CompressionPreset.values
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(_presetTitle(preset)),
                        ),
                      )
                      .toList(),
                  onChanged: _isCompressing
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _preset = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _maxResolutionCap,
                  decoration: const InputDecoration(labelText: 'Resolution cap'),
                  items: _resolutionCaps
                      .map(
                        (cap) => DropdownMenuItem<int?>(
                          value: cap,
                          child: Text(_resolutionLabel(cap)),
                        ),
                      )
                      .toList(),
                  onChanged: _isCompressing
                      ? null
                      : (value) {
                          setState(() {
                            _maxResolutionCap = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ForceCodec>(
                  value: _forceCodec,
                  decoration: const InputDecoration(labelText: 'Codec'),
                  items: ForceCodec.values
                      .map(
                        (codec) => DropdownMenuItem(
                          value: codec,
                          child: Text(_codecTitle(codec)),
                        ),
                      )
                      .toList(),
                  onChanged: _isCompressing
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _forceCodec = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxBitrateController,
                  enabled: !_isCompressing,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max bitrate (optional, bps)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _progressIntervalController,
                  enabled: !_isCompressing,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Progress interval (ms)',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allowHevc,
                  title: const Text('Allow HEVC'),
                  onChanged: _isCompressing
                      ? null
                      : (value) {
                          setState(() {
                            _allowHevc = value;
                          });
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _keepAudio,
                  title: const Text('Keep audio'),
                  onChanged: _isCompressing
                      ? null
                      : (value) {
                          setState(() {
                            _keepAudio = value;
                          });
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _keepOriginalIfLarger,
                  title: const Text('Keep original if larger'),
                  onChanged: _isCompressing
                      ? null
                      : (value) {
                          setState(() {
                            _keepOriginalIfLarger = value;
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Run',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _canCompress ? _compress : null,
                        child: const Text('Start compression'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isCompressing ? _cancel : null,
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_activeTaskId != null)
                  SelectableText(
                    'Task: $_activeTaskId',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Progress',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phase: ${_lastState?.phase.value ?? 'idle'}'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: switch (_lastState?.phase) {
                    CompressionPhase.transcoding => ((_lastState?.progressPercent ?? 0) / 100).clamp(0, 1),
                    CompressionPhase.completed => 1,
                    _ => null,
                  },
                ),
                const SizedBox(height: 8),
                Text('Progress: ${_lastState?.progressPercent ?? 0}%'),
                if (_lastState?.message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(message),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Result',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_lastResult == null)
                  const Text('No compression result yet')
                else ...[
                  Text('Output: ${_lastResult!.outputPath}'),
                  const SizedBox(height: 8),
                  Text('Codec: ${_lastResult!.codec.value}'),
                  Text('Duration: ${_lastResult!.durationMs} ms'),
                  Text('Target height: ${_lastResult!.targetHeight ?? 'original'}'),
                  Text('Target bitrate: ${_lastResult!.targetBitrate}'),
                  Text('Attempts: ${_lastResult!.attempts}'),
                  Text('Used original: ${_lastResult!.usedOriginalSource}'),
                  Text('Source size: ${_formatMb(_lastResult!.sourceSizeBytes)}'),
                  Text('Output size: ${_formatMb(_lastResult!.outputSizeBytes)}'),
                ],
                if (_lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Error: $_lastError',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _canCompress {
    return !_isPickingFile && !_isCompressing && _inputPath != null && _outputDirectoryPath != null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

const List<int?> _resolutionCaps = [null, 2160, 1440, 1080, 720, 540, 480];

String _resolutionLabel(int? value) {
  return value == null ? 'Original' : '${value}p';
}

String _presetTitle(CompressionPreset preset) {
  return switch (preset) {
    CompressionPreset.quality => 'Quality',
    CompressionPreset.balanced => 'Balanced',
    CompressionPreset.smallSize => 'Small Size',
  };
}

String _codecTitle(ForceCodec codec) {
  return switch (codec) {
    ForceCodec.auto => 'Auto',
    ForceCodec.avc => 'AVC / H.264',
    ForceCodec.hevc => 'HEVC / H.265',
  };
}

int? _parseOptionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return int.tryParse(trimmed);
}

int _parseRequiredInt(String value, {required int fallback}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }
  return int.tryParse(trimmed) ?? fallback;
}

String _formatMb(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(2)} MB';
}
