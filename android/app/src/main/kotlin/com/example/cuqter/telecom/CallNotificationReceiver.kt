package com.example.cuqter.telecom

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class CallNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("CallNotificationReceiver", "onReceive: $action")

        when (action) {
            "ACTION_ANSWER_CALL" -> {
                CallManager.answer()
            }
            "ACTION_REJECT_CALL" -> {
                CallManager.reject()
            }
        }
    }
}
