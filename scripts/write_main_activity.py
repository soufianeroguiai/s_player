import os
os.makedirs("android/app/src/main/kotlin/com/splayer/app", exist_ok=True)
content = """package com.splayer.app

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.splayer.app/pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "enterPip") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(16, 9)).build()
                        enterPictureInPictureMode(params)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}"""
with open("android/app/src/main/kotlin/com/splayer/app/MainActivity.kt", "w") as f:
    f.write(content)
print("MainActivity.kt written")
