package com.personallifeos.personal_life_os

import android.app.KeyguardManager
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * FR-108 — brankas catatan medis: berkas disimpan TERENKRIPSI.
 *
 * Kunci AES-256 dibuat sekali di Android Keystore (alias `plo_medis`), tidak
 * pernah keluar dari perangkat dan tidak bisa diekspor. Format berkas hasil:
 * [1 byte panjang IV][IV][ciphertext + tag GCM].
 *
 * Kalau perangkat/keystore menolak, jawabannya `false` — Dart lalu TIDAK
 * menyimpan berkas mentah sama sekali (tidak ada rahasia tanpa perlindungan).
 */
class BerkasMedis(private val activity: Context) {
    private val namaKanal = "lifeos/berkas_medis"
    private val aliasKunci = "plo_medis"
    private val panjangIv = 12
    private val panjangTagBit = 128

    fun pasang(flutterEngine: FlutterEngine) {
        val saluran = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, namaKanal)
        saluran.setMethodCallHandler { panggilan, hasil ->
            when (panggilan.method) {
                "didukung" -> hasil.success(punyaKeystore())
                "terkunci" -> hasil.success(terkunci())
                "enkripsi" -> hasil.success(
                    enkripsi(panggilan.argument<String>("sumber"), panggilan.argument<String>("tujuan"))
                )
                "dekripsi" -> hasil.success(
                    dekripsi(panggilan.argument<String>("sumber"), panggilan.argument<String>("tujuan"))
                )
                else -> hasil.notImplemented()
            }
        }
    }

    private fun punyaKeystore(): Boolean =
        try {
            keystore().let { true }
        } catch (_: Exception) {
            false
        }

    private fun terkunci(): Boolean {
        val manajer = activity.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        return manajer?.isKeyguardLocked ?: true
    }

    private fun keystore(): KeyStore =
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun kunci(): SecretKey {
        val ks = keystore()
        val ada = ks.getEntry(aliasKunci, null) as? KeyStore.SecretKeyEntry
        if (ada != null) return ada.secretKey
        val pembuat = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        pembuat.init(
            KeyGenParameterSpec.Builder(
                aliasKunci,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return pembuat.generateKey()
    }

    private fun enkripsi(sumber: String?, tujuan: String?): Boolean {
        if (sumber.isNullOrBlank() || tujuan.isNullOrBlank()) return false
        val asal = File(sumber)
        if (!asal.exists()) return false
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, kunci())
            val iv = cipher.iv
            val keluaran = FileOutputStream(tujuan)
            keluaran.write(iv.size)
            keluaran.write(iv)
            keluaran.use { aliran ->
                FileInputStream(asal).use { masuk ->
                    val penyangga = ByteArray(64 * 1024)
                    while (true) {
                        val dibaca = masuk.read(penyangga)
                        if (dibaca <= 0) break
                        val potongan = cipher.update(penyangga, 0, dibaca)
                        if (potongan != null && potongan.isNotEmpty()) aliran.write(potongan)
                    }
                    val akhir = cipher.doFinal()
                    if (akhir.isNotEmpty()) aliran.write(akhir)
                }
            }
            File(tujuan).length() > iv.size
        } catch (_: Exception) {
            File(tujuan).delete()
            false
        }
    }

    private fun dekripsi(sumber: String?, tujuan: String?): Boolean {
        if (sumber.isNullOrBlank() || tujuan.isNullOrBlank()) return false
        val asal = File(sumber)
        if (!asal.exists()) return false
        return try {
            val masuk = FileInputStream(asal)
            val panjang = masuk.read()
            if (panjang != panjangIv) {
                masuk.close()
                return false
            }
            val iv = ByteArray(panjang)
            if (masuk.read(iv) != panjang) {
                masuk.close()
                return false
            }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, kunci(), GCMParameterSpec(panjangTagBit, iv))
            FileOutputStream(tujuan).use { aliran ->
                val penyangga = ByteArray(64 * 1024)
                while (true) {
                    val dibaca = masuk.read(penyangga)
                    if (dibaca <= 0) break
                    val potongan = cipher.update(penyangga, 0, dibaca)
                    if (potongan != null && potongan.isNotEmpty()) aliran.write(potongan)
                }
                val akhir = cipher.doFinal()
                if (akhir.isNotEmpty()) aliran.write(akhir)
            }
            masuk.close()
            true
        } catch (_: Exception) {
            File(tujuan).delete()
            false
        }
    }
}
