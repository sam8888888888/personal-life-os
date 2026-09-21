package com.personallifeos.personal_life_os

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * FR-118 & FR-27 — kanal Android untuk lampiran (foto & rekaman suara) dan
 * pemilih berkas (sinkron lewat berkas).
 *
 * Sengaja tanpa paket Flutter tambahan: hanya API Android yang dipakai
 * (kamera lewat niat sistem, MediaRecorder, MediaPlayer, pemilih dokumen).
 * Semua berkas disalin ke folder aplikasi supaya tidak hilang saat cache
 * dibersihkan sistem.
 */
class KanalMedia(private val activity: FlutterActivity) {
    private val namaKanal = "lifeos/media"
    private var saluran: MethodChannel? = null
    private var hasilTertunda: MethodChannel.Result? = null
    private var aksiTertunda: String? = null
    private var berkasTertunda: File? = null
    private var perekam: MediaRecorder? = null
    private var berkasRekaman: File? = null
    private var pemutar: MediaPlayer? = null

    companion object {
        private const val KODE_AMBIL_FOTO = 7301
        private const val KODE_PILIH_FOTO = 7302
        private const val KODE_PILIH_BERKAS = 7303
        private const val KODE_IZIN_KAMERA = 7311
        private const val KODE_IZIN_MIKROFON = 7312
    }

    fun pasang(flutterEngine: FlutterEngine) {
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, namaKanal)
        saluran.setMethodCallHandler { panggilan, hasil ->
            when (panggilan.method) {
                "ambilFoto" -> ambilFoto(hasil)
                "pilihFoto" -> pilihFoto(hasil)
                "pilihBerkas" -> pilihBerkas(panggilan.argument<String>("mime") ?: "*/*", hasil)
                "mulaiRekam" -> mulaiRekam(hasil)
                "hentikanRekam" -> hentikanRekam(hasil)
                "putarSuara" -> putarSuara(panggilan.argument<String>("jalur"), hasil)
                "hentikanSuara" -> hentikanSuara(hasil)
                else -> hasil.notImplemented()
            }
        }
        this.saluran = saluran
    }

    // ── kamera & galeri ───────────────────────────────────────────────────────
    private fun ambilFoto(hasil: MethodChannel.Result) {
        if (!punyaIzin(Manifest.permission.CAMERA)) {
            hasilTertunda = hasil
            aksiTertunda = "ambilFoto"
            ActivityCompat.requestPermissions(
                activity, arrayOf(Manifest.permission.CAMERA), KODE_IZIN_KAMERA
            )
            return
        }
        val berkas = File(activity.cacheDir, "foto_${System.currentTimeMillis()}.jpg")
        berkasTertunda = berkas
        val alamat = FileProvider.getUriForFile(
            activity, "${activity.packageName}.berkas", berkas
        )
        val niat = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(android.provider.MediaStore.EXTRA_OUTPUT, alamat)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        mulaiNiat(niat, KODE_AMBIL_FOTO, hasil)
    }

    private fun pilihFoto(hasil: MethodChannel.Result) {
        val niat = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        mulaiNiat(niat, KODE_PILIH_FOTO, hasil)
    }

    private fun pilihBerkas(mime: String, hasil: MethodChannel.Result) {
        val niat = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        mulaiNiat(niat, KODE_PILIH_BERKAS, hasil)
    }

    private fun mulaiNiat(niat: Intent, kode: Int, hasil: MethodChannel.Result) {
        hasilTertunda = hasil
        aksiTertunda = if (kode == KODE_AMBIL_FOTO) "ambilFoto" else "pilih"
        try {
            activity.startActivityForResult(niat, kode)
        } catch (e: Exception) {
            bersihkan()
            hasil.error("gagal", e.message, null)
        }
    }

    // ── rekaman suara ─────────────────────────────────────────────────────────
    private fun mulaiRekam(hasil: MethodChannel.Result) {
        if (!punyaIzin(Manifest.permission.RECORD_AUDIO)) {
            hasilTertunda = hasil
            aksiTertunda = "mulaiRekam"
            ActivityCompat.requestPermissions(
                activity, arrayOf(Manifest.permission.RECORD_AUDIO), KODE_IZIN_MIKROFON
            )
            return
        }
        try {
            val berkas = File(activity.cacheDir, "suara_${System.currentTimeMillis()}.m4a")
            val rekam = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(activity)
            } else {
                @Suppress("DEPRECATION") MediaRecorder()
            }
            rekam.setAudioSource(MediaRecorder.AudioSource.MIC)
            rekam.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            rekam.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            rekam.setOutputFile(berkas.absolutePath)
            rekam.prepare()
            rekam.start()
            perekam = rekam
            berkasRekaman = berkas
            hasil.success("mulai")
        } catch (e: Exception) {
            bersihkanPerekam()
            hasil.error("gagal_rekam", e.message, null)
        }
    }

    private fun hentikanRekam(hasil: MethodChannel.Result) {
        val rekam = perekam
        val berkas = berkasRekaman
        if (rekam == null || berkas == null) {
            hasil.error("tidak_merekam", "Belum ada rekaman yang berjalan", null)
            return
        }
        try {
            rekam.stop()
            rekam.release()
            perekam = null
            berkasRekaman = null
            if (!berkas.exists() || berkas.length() == 0L) {
                hasil.success(null)
                return
            }
            hasil.success(berkas.absolutePath)
        } catch (e: Exception) {
            bersihkanPerekam()
            hasil.error("gagal_hentikan", e.message, null)
        }
    }

    // ── pemutar suara ─────────────────────────────────────────────────────────
    private fun putarSuara(jalur: String?, hasil: MethodChannel.Result) {
        if (jalur.isNullOrBlank()) {
            hasil.error("jalur_kosong", "Jalur berkas suara kosong", null)
            return
        }
        val berkas = File(jalur)
        if (!berkas.exists()) {
            hasil.error("tidak_ada", "Berkas suara tidak ditemukan", null)
            return
        }
        try {
            hentikanSuaraInternal()
            pemutar = MediaPlayer().apply {
                setDataSource(berkas.absolutePath)
                prepare()
                start()
            }
            hasil.success(true)
        } catch (e: Exception) {
            hasil.error("gagal_putar", e.message, null)
        }
    }

    private fun hentikanSuara(hasil: MethodChannel.Result) {
        hentikanSuaraInternal()
        hasil.success(true)
    }

    private fun hentikanSuaraInternal() {
        try {
            pemutar?.stop()
        } catch (_: Exception) {
        }
        try {
            pemutar?.release()
        } catch (_: Exception) {
        }
        pemutar = null
    }

    // ── hasil aktivitas & izin ────────────────────────────────────────────────
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val hasil = hasilTertunda ?: return
        bersihkan()
        if (resultCode != Activity.RESULT_OK) {
            hasil.success(null)
            return
        }
        try {
            when (requestCode) {
                KODE_AMBIL_FOTO -> {
                    val berkas = berkasTertunda
                    hasil.success(
                        if (berkas != null && berkas.exists() && berkas.length() > 0L)
                            berkas.absolutePath else null
                    )
                }
                KODE_PILIH_FOTO, KODE_PILIH_BERKAS -> {
                    val alamat = data?.data
                    if (alamat == null) {
                        hasil.success(null)
                        return
                    }
                    hasil.success(salinKeCache(alamat, requestCode == KODE_PILIH_FOTO))
                }
                else -> hasil.notImplemented()
            }
        } catch (e: Exception) {
            hasil.error("gagal", e.message, null)
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, hasilIzin: IntArray) {
        val hasil = hasilTertunda ?: return
        val aksi = aksiTertunda
        bersihkan()
        val diberi = hasilIzin.isNotEmpty() &&
            hasilIzin[0] == PackageManager.PERMISSION_GRANTED
        if (!diberi) {
            hasil.error("izin_ditolak", "Izin tidak diberikan pengguna", null)
            return
        }
        when (aksi) {
            "ambilFoto" -> ambilFoto(hasil)
            "mulaiRekam" -> mulaiRekam(hasil)
            else -> hasil.success(null)
        }
    }

    /// Menyalin isi dokumen pilihan pengguna ke folder cache aplikasi supaya
    /// bisa dibaca Flutter (alamat content:// tidak bisa dibuka berkas biasa).
    private fun salinKeCache(alamat: Uri, foto: Boolean): String? {
        val masukan = activity.contentResolver.openInputStream(alamat) ?: return null
        val namaAsli = activity.contentResolver
            .query(alamat, null, null, null, null)?.use { kursor ->
                val idx = kursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && kursor.moveToFirst()) kursor.getString(idx) else null
            }
        val akhiran = namaAsli?.substringAfterLast('.', missingDelimiterValue = "")
            ?.takeIf { it.isNotEmpty() }
            ?: if (foto) "jpg" else "bin"
        val berkas = File(activity.cacheDir, "pilihan_${System.currentTimeMillis()}.$akhiran")
        FileOutputStream(berkas).use { keluaran -> masukan.use { it.copyTo(keluaran) } }
        return berkas.absolutePath
    }

    private fun punyaIzin(izin: String): Boolean =
        ContextCompat.checkSelfPermission(activity, izin) == PackageManager.PERMISSION_GRANTED

    private fun bersihkan() {
        hasilTertunda = null
        aksiTertunda = null
        berkasTertunda = null
    }

    private fun bersihkanPerekam() {
        try {
            perekam?.release()
        } catch (_: Exception) {
        }
        perekam = null
        berkasRekaman = null
    }
}
