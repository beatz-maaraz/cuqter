package com.example.cuqter.telecom

import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log

class CallConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d("CallConnectionService", "onCreateIncomingConnection")
        
        val extras = request?.extras
        val callExtras = extras?.getBundle(TelecomManager.EXTRA_INCOMING_CALL_EXTRAS)
        val callerName = callExtras?.getString("caller_name") ?: "Unknown"
        val callerPic = callExtras?.getString("caller_pic")

        val connection = CallConnection(this, callerName, callerPic)
        connection.connectionCapabilities = Connection.CAPABILITY_SUPPORT_HOLD or Connection.CAPABILITY_HOLD
        connection.setInitializing()
        connection.setAddress(request?.address, TelecomManager.PRESENTATION_ALLOWED)
        connection.setCallerDisplayName(callerName, TelecomManager.PRESENTATION_ALLOWED)
        
        CallManager.currentConnection = connection
        
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d("CallConnectionService", "onCreateOutgoingConnection")
        val connection = CallConnection(this, "Outgoing", null)
        connection.setInitializing()
        connection.setAddress(request?.address, TelecomManager.PRESENTATION_ALLOWED)
        connection.setDialing()
        
        CallManager.currentConnection = connection
        
        return connection
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        super.onCreateIncomingConnectionFailed(connectionManagerPhoneAccount, request)
        Log.e("CallConnectionService", "onCreateIncomingConnectionFailed")
    }

    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        super.onCreateOutgoingConnectionFailed(connectionManagerPhoneAccount, request)
        Log.e("CallConnectionService", "onCreateOutgoingConnectionFailed")
    }
}
