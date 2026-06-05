package dev.enb.compressi.core

enum class CompressionPreset(
    internal val avcBitrateFactor: Double,
    internal val hevcBitrateFactor: Double,
) {
    BALANCED(
        avcBitrateFactor = 0.72,
        hevcBitrateFactor = 0.56,
    ),
}

