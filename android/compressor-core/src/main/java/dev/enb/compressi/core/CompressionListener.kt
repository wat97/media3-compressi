package dev.enb.compressi.core

interface CompressionListener {
    fun onStateChanged(state: CompressionState)
    fun onSuccess(result: CompressionSuccess)
    fun onFailure(failure: CompressionFailure)
}

