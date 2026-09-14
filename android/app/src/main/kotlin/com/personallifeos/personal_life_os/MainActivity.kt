package com.personallifeos.personal_life_os

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// A2: aksi cepat dari ikon aplikasi (shortcut Android) mengirim niat
/// membuka halaman tertentu lewat extra "rute". Niat itu diteruskan ke Dart
/// agar aplikasi melompat langsung ke halaman yang dituju — termasuk saat
/// aplikasi sudah berjalan (onNewIntent).
class MainActivity : FlutterActivity() {
    private val kanal = "lifeos/rute"
    private var saluranRute: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kanal)
        saluran.setMethodCallHandler { panggilan, hasil ->
            if (panggilan.method == "ruteAwal") {
                hasil.success(ruteDari(intent))
            } else {
                hasil.notImplemented()
            }
        }
        saluranRute = saluran
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val rute = ruteDari(intent)
        if (rute != null) {
            saluranRute?.invokeMethod("ruteBaru", rute)
        }
    }

    private fun ruteDari(intent: Intent?): String? {
        val rute = intent?.getStringExtra("rute")
        return if (rute.isNullOrBlank()) null else rute
    }
}
