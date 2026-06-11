/// Maximum output height cap for compression.
///
/// The engine never upscales. For example, [p1080] keeps 720p input at 720p and
/// caps 4K input to 1080p.
enum CompressionResolutionCap {
  /// Keep source resolution.
  original(null, 'Original'),

  /// Cap output height to 2160p.
  p2160(2160, '2160p'),

  /// Cap output height to 1440p.
  p1440(1440, '1440p'),

  /// Cap output height to 1080p.
  p1080(1080, '1080p'),

  /// Cap output height to 720p.
  p720(720, '720p'),

  /// Cap output height to 540p.
  p540(540, '540p'),

  /// Cap output height to 480p.
  p480(480, '480p');

  const CompressionResolutionCap(this.height, this.label);

  /// Native target height sent to platform code, or `null` for original.
  final int? height;

  /// Human-readable label for UI controls.
  final String label;

  /// Creates a resolution cap from a native height value.
  static CompressionResolutionCap fromHeight(int? height) {
    return CompressionResolutionCap.values.firstWhere(
      (item) => item.height == height,
      orElse: () => CompressionResolutionCap.p1080,
    );
  }
}
