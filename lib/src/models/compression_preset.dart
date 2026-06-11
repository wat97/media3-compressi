/// Compression policy preset used by the native engine.
enum CompressionPreset {
  /// Prioritizes visual quality over output size.
  quality('quality'),

  /// Default preset for user-facing compression.
  balanced('balanced'),

  /// Prioritizes smaller output size over visual quality.
  smallSize('small_size');

  const CompressionPreset(this.value);

  /// Serialized value sent through the platform channel.
  final String value;

  /// Creates a preset from a serialized platform-channel [value].
  static CompressionPreset fromValue(String value) {
    return CompressionPreset.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CompressionPreset.balanced,
    );
  }
}
