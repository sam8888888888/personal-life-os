package com.personallifeos.personal_life_os

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FR-58 — kanal suara Android memakai SpeechRecognizer bawaan sistem.
 *
 * Prinsip:
 *  - hanya MENGEMBALIKAN teks hasil pengenalan; rekaman tidak disimpan dan
 *    tidak dikirim oleh aplikasi ini;
 *  - izin mikrofon diminta lewat dialog sistem saat benar-benar dipakai;
 *  - kalau perangkat tidak punya pengenal suara, dijawab apa adanya
 *    (`tersedia` = false) supaya layar bisa menyarankan menulis saja;
 *  - hasil selalu dibatasi waktu (bawaan 15 detik) supaya tidak menggantung.
 */
class KanalSuara(private val activity: FlutterActivity) {
    private val namaKanal = "lifeos/suara"
    private var pengenal: SpeechRecognizer? = null
    private var hasilTertunda: MethodChannel.Result? = null
    private var sudahSelesai = false

    companion object {
        private const val KODE_IZIN_MIKROFON = 9401
    }

    fun pasang(flutterEngine: FlutterEngine) {
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, namaKanal)
        saluran.setMethodCallHandler { panggilan, hasil ->
            when (panggilan.method) {
                "tersedia" -> hasil.success(
                    SpeechRecognizer.isRecognitionAvailable(activity)
                )
                "dengar" -> {
                    val locale = panggilan.argument<String>("locale") ?: "id-ID"
                    val detikMaks = (panggilan.argument<Int>("detikMaks") ?: 15)
                        .coerceIn(3, 60)
                    mulaiDengar(locale, detikMaks, hasil)
                }
                else -> hasil.notImplemented()
            }
        }
    }

    private fun izinMikrofon(): Boolean = ContextCompat.checkSelfPermission(
        activity, Manifest.permission.RECORD_AUDIO
    ) == PackageManager.PERMISSION_GRANTED

    private fun mulaiDengar(
        locale: String,
        detikMaks: Int,
        hasil: MethodChannel.Result
    ) {
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            hasil.error("tidak_tersedia", "Pengenal suara tidak ada", null)
            return
        }
        if (!izinMikrofon()) {
            hasil.error("izin_ditolak", "Izin mikrofon belum diberikan", null)
            return
        }
        if (hasilTertunda != null) {
            hasil.error("sedang_jalan", "Masih mendengarkan kalimat sebelumnya", null)
            return
        }
        hasilTertunda = hasil
        sudahSelesai = false

        activity.runOnUiThread {
            bersihkanPengenal()
            val p = SpeechRecognizer.createSpeechRecognizer(activity)
            pengenal = p
            p.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}

                override fun onError(error: Int) {
                    val kode = when (error) {
                        SpeechRecognizer.ERROR_NO_MATCH,
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "kosong"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "sibuk"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "izin_ditolak"
                        else -> "gagal_$error"
                    }
                    gagal(kode)
                }

                override fun onResults(results: Bundle?) {
                    val daftar = results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.filter { it.isNotBlank() }
                        .orEmpty()
                    if (daftar.isEmpty()) {
                        gagal("kosong")
                        return
                    }
                    val balasan = HashMap<String, Any>()
                    balasan["teks"] = daftar.first()
                    balasan["alternatif"] = daftar
                    berhasil(balasan)
                }
            })
            val niat = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                    2500L
                )
            }
            try {
                p.startListening(niat)
            } catch (e: Exception) {
                gagal("gagal_start")
                return@runOnUiThread
            }
            Handler(Looper.getMainLooper()).postDelayed({
                if (!sudahSelesai) {
                    try {
                        pengenal?.stopListening()
                    } catch (_: Exception) {
                    }
                    gagal("kosong")
                }
            }, detikMaks * 1000L)
        }
    }

    private fun berhasil(nilai: HashMap<String, Any>) {
        if (sudahSelesai) return
        sudahSelesai = true
        val hasil = hasilTertunda
        hasilTertunda = null
        bersihkanPengenal()
        hasil?.success(nilai)
    }

    private fun gagal(kode: String) {
        if (sudahSelesai) return
        sudahSelesai = true
        val hasil = hasilTertunda
        hasilTertunda = null
        bersihkanPengenal()
        hasil?.error(kode, "Pengenalan suara: $kode", null)
    }

    private fun bersihkanPengenal() {
        try {
            pengenal?.destroy()
        } catch (_: Exception) {
        }
        pengenal = null
    }

    /** Diteruskan MainActivity saat dialog izin mikrofon selesai. */
    fun onRequestPermissionsResult(requestCode: Int, hasilIzin: IntArray) {
        if (requestCode != KODE_IZIN_MIKROFON) return
        val hasil = hasilTertunda ?: return
        hasilTertunda = null
        sudahSelesai = true
        val diberi = hasilIzin.isNotEmpty() &&
            hasilIzin[0] == PackageManager.PERMISSION_GRANTED
        if (diberi) {
            hasil.error("izin_diberi", "Ulangi mendengarkan", null)
        } else {
            hasil.error("izin_ditolak", "Izin mikrofon tidak diberikan", null)
        }
    }

    /** Dipakai MainActivity saat meminta izin mikrofon dari luar kanal ini. */
    fun mintaIzinMikrofon() {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            KODE_IZIN_MIKROFON
        )
    }

    /** Aktifitas ini dipakai saat mengecek hasil izin. */
    fun aktivitas(): Activity = activity
}
