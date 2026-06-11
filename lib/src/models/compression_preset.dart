enum CompressionPreset {
  quality('quality'),
  balanced('balanced'),
  smallSize('small_size');

  const CompressionPreset(this.value);

  final String value;

  static CompressionPreset fromValue(String value) {
    return CompressionPreset.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CompressionPreset.balanced,
    );
  }
}
