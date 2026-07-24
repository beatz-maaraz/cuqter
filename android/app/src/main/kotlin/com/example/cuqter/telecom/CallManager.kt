package com.example.cuqter.telecom

import android.util.Log

object CallManager {
    var currentConnection: CallConnection? = null

    fun answer() {
        Log.d("CallManager", "Answering call")
        currentConnection?.onAnswer()
    }

    fun reject() {
        Log.d("CallManager", "Rejecting call")
        currentConnection?.onReject()
    }

    fun disconnect() {
        Log.d("CallManager", "Disconnecting call")
        currentConnection?.onDisconnect()
    }
}
