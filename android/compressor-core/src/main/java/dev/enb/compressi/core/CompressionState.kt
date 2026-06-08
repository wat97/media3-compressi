package dev.enb.compressi.core

sealed interface CompressionState {
    data object Preparing : CompressionState
    data class Transcoding(val progressPercent: Int) : CompressionState
    data object Finalizing : CompressionState
    data object Completed : CompressionState
    data class Failed(val failure: CompressionFailure) : CompressionState
    data object Cancelled : CompressionState
}

