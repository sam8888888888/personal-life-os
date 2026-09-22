package com.personallifeos.personal_life_os

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FR-39 — kanal SMS Android (HANYA baca, HANYA setelah diizinkan pengguna).
 *
 * Prinsip yang dipegang:
 *  - izin READ_SMS diminta lewat dialog sistem, tidak pernah diam-diam;
 *  - kanal hanya mengembalikan pengirim, isi pesan, dan waktu — penyaringan
 *    bank & penguraian dilakukan di Dart supaya aturannya bisa diuji;
 *  - tidak ada satu pun data yang dikirim ke jaringan oleh kanal ini;
 *  - kalau izin belum ada, dijawab kode `izin_ditolak` (bukan diam).
 */
class KanalSms(private val activity: FlutterActivity) {
    private val namaKanal = "lifeos/sms"
    private var hasilIzinTertunda: MethodChannel.Result? = null

    companion object {
        private const val KODE_IZIN_SMS = 9501
        private val KOLOM = arrayOf("_id", "address", "body", "date")
    }

    fun pasang(flutterEngine: FlutterEngine) {
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, namaKanal)
        saluran.setMethodCallHandler { panggilan, hasil ->
            when (panggilan.method) {
                "tersedia" -> hasil.success(true)
                "izinDiberikan" -> hasil.success(izinSms())
                "mintaIzin" -> mintaIzin(hasil)
                "bacaSejak" -> bacaSejak(
                    panggilan.argument<Number>("sejakMs")?.toLong() ?: 0L,
                    (panggilan.argument<Int>("batas") ?: 200).coerceIn(1, 500),
                    hasil
                )
                else -> hasil.notImplemented()
            }
        }
    }

    private fun izinSms(): Boolean = ContextCompat.checkSelfPermission(
        activity, Manifest.permission.READ_SMS
    ) == PackageManager.PERMISSION_GRANTED

    private fun mintaIzin(hasil: MethodChannel.Result) {
        if (izinSms()) {
            hasil.success(true)
            return
        }
        if (hasilIzinTertunda != null) {
            hasil.error("sedang_jalan", "Permintaan izin sebelumnya belum selesai", null)
            return
        }
        hasilIzinTertunda = hasil
        activity.runOnUiThread {
            ActivityCompat.requestPermissions(
                activity, arrayOf(Manifest.permission.READ_SMS), KODE_IZIN_SMS
            )
        }
    }

    private fun bacaSejak(sejakMs: Long, batas: Int, hasil: MethodChannel.Result) {
        if (!izinSms()) {
            hasil.error("izin_ditolak", "Izin baca SMS belum diberikan", null)
            return
        }
        val daftar = ArrayList<HashMap<String, Any>>()
        try {
            val kursor = activity.contentResolver.query(
                Uri.parse("content://sms/inbox"),
                KOLOM,
                "date >= ?",
                arrayOf(sejakMs.toString()),
                "date DESC LIMIT $batas"
            )
            kursor?.use { k ->
                val idxId = k.getColumnIndex("_id")
                val idxAlamat = k.getColumnIndex("address")
                val idxIsi = k.getColumnIndex("body")
                val idxWaktu = k.getColumnIndex("date")
                while (k.moveToNext()) {
                    val isi = if (idxIsi >= 0) k.getString(idxIsi) else null ?: continue
                    val baris = HashMap<String, Any>()
                    baris["id"] = if (idxId >= 0) k.getInt(idxId) else -1
                    baris["pengirim"] = if (idxAlamat >= 0) {
                        k.getString(idxAlamat) ?: ""
                    } else ""
                    baris["isi"] = isi
                    baris["waktuMs"] = if (idxWaktu >= 0) k.getLong(idxWaktu) else 0L
                    daftar.add(baris)
                }
            }
        } catch (e: SecurityException) {
            hasil.error("izin_ditolak", "Izin baca SMS dicabut sistem", null)
            return
        } catch (e: Exception) {
            hasil.error("gagal_baca", "Gagal membaca kotak masuk: ${e.message}", null)
            return
        }
        hasil.success(daftar)
    }

    /** Diteruskan MainActivity saat dialog izin SMS selesai. */
    fun onRequestPermissionsResult(requestCode: Int, hasilIzin: IntArray) {
        if (requestCode != KODE_IZIN_SMS) return
        val hasil = hasilIzinTertunda ?: return
        hasilIzinTertunda = null
        val diberi = hasilIzin.isNotEmpty() &&
            hasilIzin[0] == PackageManager.PERMISSION_GRANTED
        hasil.success(diberi)
    }
}
