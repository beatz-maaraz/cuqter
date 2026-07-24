package com.example.cuqter.telecom

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log

class TelecomHelper(private val context: Context) {

    private val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
    private val componentName = ComponentName(context, CallConnectionService::class.java)
    val phoneAccountHandle = PhoneAccountHandle(componentName, "CuqterCallAccount")

    fun registerPhoneAccount() {
        val phoneAccount = PhoneAccount.builder(phoneAccountHandle, "Cuqter")
            .setCapabilities(PhoneAccount.CAPABILITY_SELF_MANAGED)
            .addSupportedUriScheme(PhoneAccount.SCHEME_TEL)
            .build()
        telecomManager.registerPhoneAccount(phoneAccount)
        Log.d("TelecomHelper", "PhoneAccount registered")
    }

    fun addNewIncomingCall(callerName: String, number: String, callerPic: String?) {
        val extras = Bundle()
        val uri = Uri.fromParts(PhoneAccount.SCHEME_TEL, number, null)
        extras.putParcelable(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, uri)
        
        val callExtras = Bundle()
        callExtras.putString("caller_name", callerName)
        callExtras.putString("caller_pic", callerPic)
        extras.putBundle(TelecomManager.EXTRA_INCOMING_CALL_EXTRAS, callExtras)
        
        try {
            telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
            Log.d("TelecomHelper", "addNewIncomingCall called for $number with name $callerName")
        } catch (e: Exception) {
            Log.e("TelecomHelper", "Error adding new incoming call", e)
        }
    }
}
