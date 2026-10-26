package com.example.mobile

import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.media.AudioAttributes
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var arrivalRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ARRIVAL_SOUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "playNotificationSound") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    val soundUri: Uri? = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    if (soundUri == null) {
                        result.error("NO_NOTIFICATION_SOUND", "No default notification sound is configured", null)
                    } else {
                        arrivalRingtone?.stop()
                        arrivalRingtone = RingtoneManager.getRingtone(this, soundUri)?.apply {
                            audioAttributes = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                            play()
                        }
                        if (arrivalRingtone == null) {
                            result.error("SOUND_UNAVAILABLE", "Android could not load the notification sound", null)
                        } else {
                            result.success(null)
                        }
                    }
                } catch (error: Exception) {
                    result.error("SOUND_PLAYBACK_FAILED", error.message, null)
                }
            }
    }

    companion object {
        private const val ARRIVAL_SOUND_CHANNEL = "com.arrivioai.mobile/arrival_alert"
    }
}
