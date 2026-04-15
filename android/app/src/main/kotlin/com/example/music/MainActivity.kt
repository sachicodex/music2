package com.example.music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var actionEventSink: EventChannel.EventSink? = null
    private val pendingActions = ArrayDeque<Map<String, String>>()

    private val actionReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val command = intent?.getStringExtra(MediaNotificationService.EXTRA_COMMAND) ?: return
                val payload = mapOf("action" to command)
                val sink = actionEventSink
                if (sink == null) {
                    pendingActions.addLast(payload)
                } else {
                    sink.success(payload)
                }
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler(::handleMethodCall)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    actionEventSink = events
                    while (pendingActions.isNotEmpty()) {
                        events.success(pendingActions.removeFirst())
                    }
                }

                override fun onCancel(arguments: Any?) {
                    actionEventSink = null
                }
            }
        )
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(MediaNotificationService.ACTION_MEDIA_COMMAND_BROADCAST)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(actionReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(actionReceiver, filter)
        }
    }

    override fun onStop() {
        runCatching { unregisterReceiver(actionReceiver) }
        super.onStop()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateNotification" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("invalid_args", "Expected map arguments.", null)
                    return
                }
                startMediaService(args)
                result.success(null)
            }
            "stopNotification" -> {
                val intent = Intent(this, MediaNotificationService::class.java).apply {
                    action = MediaNotificationService.ACTION_STOP_NOTIFICATION
                }
                startService(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startMediaService(args: Map<*, *>) {
        val intent =
            Intent(this, MediaNotificationService::class.java).apply {
                action = MediaNotificationService.ACTION_UPDATE_NOTIFICATION
                putExtra(MediaNotificationService.EXTRA_TITLE, args["title"] as? String ?: "")
                putExtra(MediaNotificationService.EXTRA_ARTIST, args["artist"] as? String ?: "")
                putExtra(MediaNotificationService.EXTRA_ALBUM, args["album"] as? String ?: "")
                putExtra(MediaNotificationService.EXTRA_ART_URI, args["artUri"] as? String)
                putExtra(MediaNotificationService.EXTRA_IS_PLAYING, args["isPlaying"] as? Boolean ?: false)
                putExtra(MediaNotificationService.EXTRA_POSITION_MS, (args["positionMs"] as? Number)?.toLong() ?: 0L)
                putExtra(MediaNotificationService.EXTRA_DURATION_MS, (args["durationMs"] as? Number)?.toLong() ?: 0L)
            }
        startForegroundService(intent)
    }

    companion object {
        private const val METHOD_CHANNEL = "com.example.music/media_notification"
        private const val EVENT_CHANNEL = "com.example.music/media_notification_actions"
    }
}
