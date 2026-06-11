/// Codec override for native compression.
enum ForceCodec {
  /// Let the native engine choose and fallback when needed.
  auto('auto'),

  /// Force AVC/H.264 output.
  avc('avc'),

  /// Force HEVC/H.265 output when supported.
  hevc('hevc');

  const ForceCodec(this.value);

  /// Serialized value sent through the platform channel.
  final String value;

  /// Creates a codec override from a serialized platform-channel [value].
  static ForceCodec fromValue(String value) {
    return ForceCodec.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ForceCodec.auto,
    );
  }
}
