package com.misbahkhan.life_os

import android.content.Context
import android.media.AudioManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Adds a small "media keys" bridge: Focus can play, pause or skip whatever music app is
 * playing (Spotify, YouTube Music, YouTube...), the same way headphone buttons do.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "life_os/media").setMethodCallHandler { call, result ->
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            fun press(code: Int) {
                audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
            }
            when (call.method) {
                "play" -> { press(KeyEvent.KEYCODE_MEDIA_PLAY); result.success(true) }
                "pause" -> { press(KeyEvent.KEYCODE_MEDIA_PAUSE); result.success(true) }
                "toggle" -> { press(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE); result.success(true) }
                "next" -> { press(KeyEvent.KEYCODE_MEDIA_NEXT); result.success(true) }
                "previous" -> { press(KeyEvent.KEYCODE_MEDIA_PREVIOUS); result.success(true) }
                "isPlaying" -> result.success(audio.isMusicActive)
                else -> result.notImplemented()
            }
        }
    }
}
