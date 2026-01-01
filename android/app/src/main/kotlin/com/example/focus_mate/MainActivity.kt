package com.example.focus_mate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "accessibility_events"
    private var eventSink: EventChannel.EventSink? = null
    private var myReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events

                    myReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            val pkg = intent?.getStringExtra("package")
                            pkg?.let { eventSink?.success(it) }
                        }
                    }

                    val filter = IntentFilter("com.block_app.ACTION_SHOW_OVERLAY")

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        registerReceiver(myReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(myReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    myReceiver?.let {
                        unregisterReceiver(it)
                        myReceiver = null
                    }
                    eventSink = null
                }
            }
        )
    }
}
