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
    private val kanalBagikan = "lifeos/bagikan"
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
        pasangKanalBagikan(flutterEngine)
    }

    /// FR-45: bagikan berkas laporan (PDF/CSV) lewat lembar berbagi Android.
    private fun pasangKanalBagikan(flutterEngine: FlutterEngine) {
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kanalBagikan)
        saluran.setMethodCallHandler { panggilan, hasil ->
            if (panggilan.method != "bagikan") {
                hasil.notImplemented()
                return@setMethodCallHandler
            }
            val jalur = panggilan.argument<String>("jalur")
            val judul = panggilan.argument<String>("judul") ?: "Bagikan berkas"
            val jenis = panggilan.argument<String>("jenis") ?: "application/pdf"
            if (jalur.isNullOrBlank()) {
                hasil.error("jalur_kosong", "Jalur berkas kosong", null)
                return@setMethodCallHandler
            }
            val berkas = java.io.File(jalur)
            if (!berkas.exists()) {
                hasil.error("tidak_ada", "Berkas tidak ditemukan", null)
                return@setMethodCallHandler
            }
            try {
                val alamat = androidx.core.content.FileProvider.getUriForFile(
                    this, "$packageName.berkas", berkas
                )
                val kirim = Intent(Intent.ACTION_SEND).apply {
                    type = jenis
                    putExtra(Intent.EXTRA_STREAM, alamat)
                    putExtra(Intent.EXTRA_SUBJECT, judul)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(kirim, judul))
                hasil.success(true)
            } catch (e: Exception) {
                hasil.error("gagal", e.message, null)
            }
        }
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
