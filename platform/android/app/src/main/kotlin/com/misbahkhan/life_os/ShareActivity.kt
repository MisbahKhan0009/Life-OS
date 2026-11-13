package com.misbahkhan.life_os

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text and links shared from other apps. Runs the small `shareMain` Dart entry point
 * in a transparent window, so the app you shared from stays visible and keeps running behind it.
 */
class ShareActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "life_os/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "getShared" -> {
                    val i: Intent? = intent
                    result.success(
                        mapOf(
                            "text" to (i?.getStringExtra(Intent.EXTRA_TEXT) ?: ""),
                            "subject" to (i?.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""),
                        )
                    )
                }
                "close" -> {
                    result.success(null)
                    finish()
                    overridePendingTransition(0, android.R.anim.fade_out)
                }
                else -> result.notImplemented()
            }
        }
    }
}
