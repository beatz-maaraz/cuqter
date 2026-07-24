package com.example.cuqter

import android.os.Bundle
import com.example.cuqter.telecom.TelecomHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var telecomHelper: TelecomHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        telecomHelper = TelecomHelper(this)
        telecomHelper.registerPhoneAccount()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.cuqter/telecom").setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingCall" -> {
                    val name = call.argument<String>("name") ?: "Unknown"
                    val number = call.argument<String>("number") ?: "000000"
                    val avatar = call.argument<String>("avatar")
                    telecomHelper.addNewIncomingCall(name, number, avatar)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
