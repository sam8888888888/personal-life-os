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
    private val RUTE_KARTU_DARURAT = "/kesehatan/kartu-darurat"
    private val kanalBagikan = "lifeos/bagikan"
    private val kanalBuka = "lifeos/buka"
    private var saluranRute: MethodChannel? = null
    private val kanalMedia = KanalMedia(this)
    // FR-26 / FR-22 / FR-31 & FR-151
    private val kanalKunci = KanalKunci(this)
    private val kanalLencana = KanalLencana(this)
    private val kanalWidget = KanalWidget(this)
    // FR-58 (suara) & FR-39 (SMS bank)
    private val kanalSuara = KanalSuara(this)
    private val kanalSms = KanalSms(this)
    // FR-38/FR-50 — OCR di perangkat (tagihan dari foto, struk, nota).
    private val kanalOcr = KanalOcr(this)

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // FR-117: pintasan kartu darurat boleh tampil tanpa membuka kunci.
        tampilkanDiAtasKunci(ruteDari(intent))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kanal)
        saluran.setMethodCallHandler { panggilan, hasil ->
            when (panggilan.method) {
                "ruteAwal" -> hasil.success(ruteDari(intent))
                // FR-151: aksi dari widget/aksi cepat ikon.
                "aksiAwal" -> hasil.success(aksiDari(intent))
                else -> hasil.notImplemented()
            }
        }
        saluranRute = saluran
        pasangKanalBagikan(flutterEngine)
        pasangKanalBuka(flutterEngine)
        // FR-118 & FR-27: lampiran foto/suara + pemilih berkas.
        kanalMedia.pasang(flutterEngine)
        // FR-26 / FR-22 / FR-31 & FR-151
        kanalKunci.pasang(flutterEngine.dartExecutor.binaryMessenger)
        kanalLencana.pasang(flutterEngine.dartExecutor.binaryMessenger)
        kanalWidget.pasang(flutterEngine.dartExecutor.binaryMessenger)
        // FR-98 — arah hadap perangkat untuk layar kiblat.
        KanalKompas.pasang(flutterEngine, this)
        // FR-58 — pengenalan suara bawaan Android.
        kanalSuara.pasang(flutterEngine)
        // FR-39 — baca SMS bank (hanya bila izin diberikan).
        kanalSms.pasang(flutterEngine)
        kanalOcr.pasang(flutterEngine)
    }

    /// FR-49: buka tautan ke aplikasi lain (WhatsApp / SMS / Telegram).
    /// Bila tidak ada aplikasi penerima, dijawab `false` — bukan galat,
    /// supaya Dart bisa memberi tahu pengguna apa adanya.
    private fun pasangKanalBuka(flutterEngine: FlutterEngine) {
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kanalBuka)
        saluran.setMethodCallHandler { panggilan, hasil ->
            if (panggilan.method != "bukaTautan") {
                hasil.notImplemented()
                return@setMethodCallHandler
            }
            val tautan = panggilan.argument<String>("tautan")
            if (tautan.isNullOrBlank()) {
                hasil.error("tautan_kosong", "Tautan kosong", null)
                return@setMethodCallHandler
            }
            try {
                startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(tautan)))
                hasil.success(true)
            } catch (e: android.content.ActivityNotFoundException) {
                hasil.success(false)
            } catch (e: Exception) {
                hasil.error("gagal", e.message, null)
            }
        }
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        kanalMedia.onActivityResult(requestCode, resultCode, data)
        // FR-26: hasil permintaan kunci perangkat.
        kanalKunci.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        kanalMedia.onRequestPermissionsResult(requestCode, grantResults)
        kanalSuara.onRequestPermissionsResult(requestCode, grantResults)
        kanalSms.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val rute = ruteDari(intent)
        tampilkanDiAtasKunci(rute)
        val aksi = aksiDari(intent)
        when {
            // FR-151: aksi lebih diutamakan daripada sekadar membuka halaman.
            aksi != null -> saluranRute?.invokeMethod("aksiBaru", aksi)
            rute != null -> saluranRute?.invokeMethod("ruteBaru", rute)
        }
    }

    /**
     * FR-151: aksi yang datang dari widget layar utama / aksi cepat ikon
     * (`aksi` wajib, `id` opsional). Dijalankan Dart saat aplikasi terbuka.
     */
    private fun aksiDari(intent: Intent?): Map<String, String>? {
        val aksi = intent?.getStringExtra("aksi")
        if (aksi.isNullOrBlank()) return null
        val peta = HashMap<String, String>()
        peta["aksi"] = aksi
        intent.getStringExtra("id")?.let { if (it.isNotBlank()) peta["id"] = it }
        intent.getStringExtra("judul")?.let { if (it.isNotBlank()) peta["judul"] = it }
        return peta
    }

    /// Kartu darurat (FR-117) diizinkan tampil di atas layar kunci.
    private fun tampilkanDiAtasKunci(rute: String?) {
        val darurat = rute == RUTE_KARTU_DARURAT
        setShowWhenLocked(darurat)
        setTurnScreenOn(darurat)
    }

    private fun ruteDari(intent: Intent?): String? {
        val rute = intent?.getStringExtra("rute")
        return if (rute.isNullOrBlank()) null else rute
    }
}
