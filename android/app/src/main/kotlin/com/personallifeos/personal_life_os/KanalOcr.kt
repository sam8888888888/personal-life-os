package com.personallifeos.personal_life_os

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File

/**
 * FR-38 & FR-50 — kanal OCR di perangkat (ML Kit, model TERBUNDEL).
 *
 * Prinsip yang dipegang:
 *  - foto diproses di HP; tidak ada gambar atau teks yang dikirim ke server
 *    mana pun oleh aplikasi ini;
 *  - model terbundel di APK, jadi OCR tetap jalan tanpa internet;
 *  - kanal hanya MENGEMBALIKAN teks + posisi baris; semua tafsir (nominal,
 *    tanggal, nama tagihan) dikerjakan di Dart supaya bisa diuji;
 *  - kalau gambar tidak terbaca, dijawab kode `kosong` — bukan tebakan.
 */
class KanalOcr(private val activity: FlutterActivity) {
    private val namaKanal = "lifeos/ocr"

    fun pasang(flutterEngine: FlutterEngine) {
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, namaKanal)
        saluran.setMethodCallHandler { panggilan, hasil ->
            when (panggilan.method) {
                // Model terbundel: selalu tersedia selama APK ini terpasang.
                "tersedia" -> hasil.success(true)
                "bacaTeks" -> {
                    val jalur = panggilan.argument<String>("jalur")
                    if (jalur.isNullOrBlank()) {
                        hasil.error("berkas_kosong", "Jalur berkas kosong", null)
                    } else {
                        bacaTeks(jalur, hasil)
                    }
                }
                else -> hasil.notImplemented()
            }
        }
    }

    private fun bacaTeks(jalur: String, hasil: MethodChannel.Result) {
        val berkas = File(jalur)
        if (!berkas.exists()) {
            hasil.error("berkas_tidak_ada", "Berkas tidak ditemukan: $jalur", null)
            return
        }
        val pengenal = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val gambar = try {
            InputImage.fromFilePath(activity, Uri.fromFile(berkas))
        } catch (e: Exception) {
            hasil.error("gagal_baca", "Gambar tidak bisa dibuka: ${e.message}", null)
            return
        }

        pengenal.process(gambar)
            .addOnSuccessListener { teks ->
                val baris = ArrayList<HashMap<String, Any>>()
                for (blok in teks.textBlocks) {
                    for (satuBaris in blok.lines) {
                        val isi = satuBaris.text
                        if (isi.isBlank()) continue
                        val barisPeta = HashMap<String, Any>()
                        barisPeta["teks"] = isi
                        val kotak = satuBaris.boundingBox
                        if (kotak != null) {
                            barisPeta["kiri"] = kotak.left
                            barisPeta["atas"] = kotak.top
                            barisPeta["kanan"] = kotak.right
                            barisPeta["bawah"] = kotak.bottom
                        }
                        baris.add(barisPeta)
                    }
                }
                val balasan = HashMap<String, Any>()
                balasan["teks"] = teks.text
                balasan["baris"] = baris
                balasan["jumlahBaris"] = baris.size
                hasil.success(balasan)
                pengenal.close()
            }
            .addOnFailureListener { e ->
                hasil.error("gagal_baca", "Pengenalan teks gagal: ${e.message}", null)
                pengenal.close()
            }
    }
}
