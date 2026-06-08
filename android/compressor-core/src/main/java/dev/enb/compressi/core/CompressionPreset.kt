package dev.enb.compressi.core

enum class CompressionPreset(
    internal val avcBitrateFactor: Double,
    internal val hevcBitrateFactor: Double,
) {
    QUALITY(
        avcBitrateFactor = 0.86,
        hevcBitrateFactor = 0.68,
    ),
    BALANCED(
        avcBitrateFactor = 0.72,
        hevcBitrateFactor = 0.56,
    ),
    SMALL_SIZE(
        avcBitrateFactor = 0.54,
        hevcBitrateFactor = 0.42,
    ),
}
