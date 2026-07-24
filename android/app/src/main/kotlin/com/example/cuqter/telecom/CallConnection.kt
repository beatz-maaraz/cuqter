package com.example.cuqter.telecom

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.cuqter.MainActivity
import com.example.cuqter.R
import java.net.URL
import kotlin.concurrent.thread

class CallConnection(
    private val context: Context,
    private val callerName: String,
    private val callerPic: String?
) : Connection() {

    private val notificationId = 101
    private val channelId = "incoming_calls"

    init {
        createNotificationChannel()
    }

    override fun onShowIncomingCallUi() {
        Log.d("CallConnection", "onShowIncomingCallUi for $callerName")
        showNotification()
    }

    override fun onAnswer() {
        Log.d("CallConnection", "onAnswer")
        setActive()
        cancelNotification()
    }

    override fun onReject() {
        Log.d("CallConnection", "onReject")
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
        cancelNotification()
        destroy()
    }

    override fun onDisconnect() {
        Log.d("CallConnection", "onDisconnect")
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        cancelNotification()
        destroy()
    }

    override fun onAbort() {
        Log.d("CallConnection", "onAbort")
        setDisconnected(DisconnectCause(DisconnectCause.CANCELED))
        cancelNotification()
        destroy()
    }

    private fun showNotification() {
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val answerIntent = Intent(context, CallNotificationReceiver::class.java).apply {
            action = "ACTION_ANSWER_CALL"
        }
        val answerPendingIntent = PendingIntent.getBroadcast(context, 1, answerIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val rejectIntent = Intent(context, CallNotificationReceiver::class.java).apply {
            action = "ACTION_REJECT_CALL"
        }
        val rejectPendingIntent = PendingIntent.getBroadcast(context, 2, rejectIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("Incoming Call")
            .setContentText(callerName)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(pendingIntent, true)
            .addAction(R.mipmap.launcher_icon, "Answer", answerPendingIntent)
            .addAction(R.mipmap.launcher_icon, "Decline", rejectPendingIntent)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())

        // Load avatar if available
        if (!callerPic.isNullOrEmpty()) {
            thread {
                try {
                    val url = URL(callerPic)
                    val connection = url.openConnection()
                    connection.doInput = true
                    connection.connect()
                    val input = connection.getInputStream()
                    val bitmap = BitmapFactory.decodeStream(input)
                    if (bitmap != null) {
                        Handler(Looper.getMainLooper()).post {
                            builder.setLargeIcon(circleBitmap(bitmap))
                            notificationManager.notify(notificationId, builder.build())
                        }
                    }
                } catch (e: Exception) {
                    Log.e("CallConnection", "Error loading profile pic", e)
                }
            }
        }
    }

    private fun circleBitmap(bitmap: Bitmap): Bitmap {
        // Basic cropping to square for now, circular would be better but requires more code
        val size = Math.min(bitmap.width, bitmap.height)
        return Bitmap.createBitmap(bitmap, (bitmap.width - size) / 2, (bitmap.height - size) / 2, size, size)
    }

    private fun cancelNotification() {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(notificationId)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Incoming Calls"
            val descriptionText = "Notification channel for incoming calls"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, name, importance).apply {
                description = descriptionText
                setSound(null, null) // Use system default or custom ringtone handled elsewhere
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onCallAudioStateChanged(state: CallAudioState?) {
        Log.d("CallConnection", "onCallAudioStateChanged: $state")
    }
}
