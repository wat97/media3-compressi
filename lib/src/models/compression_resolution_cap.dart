enum CompressionResolutionCap {
  original(null, 'Original'),
  p2160(2160, '2160p'),
  p1440(1440, '1440p'),
  p1080(1080, '1080p'),
  p720(720, '720p'),
  p540(540, '540p'),
  p480(480, '480p');

  const CompressionResolutionCap(this.height, this.label);

  final int? height;
  final String label;

  static CompressionResolutionCap fromHeight(int? height) {
    return CompressionResolutionCap.values.firstWhere(
      (item) => item.height == height,
      orElse: () => CompressionResolutionCap.p1080,
    );
  }
}
