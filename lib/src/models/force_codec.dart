enum ForceCodec {
  auto('auto'),
  avc('avc'),
  hevc('hevc');

  const ForceCodec(this.value);

  final String value;

  static ForceCodec fromValue(String value) {
    return ForceCodec.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ForceCodec.auto,
    );
  }
}

