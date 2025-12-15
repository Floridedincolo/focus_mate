package com.example.focus_mate

import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import com.block_app.AppBlockingService

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val intent = Intent(this, AppBlockingService::class.java)
        ContextCompat.startForegroundService(this, intent)
    }
}
