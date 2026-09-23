package com.personallifeos.lifeos_brankas

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Brankas rahasia perangkat (hasil audit 23 Sep 2026, temuan P0-3, P1-2, P2-2).
 *
 * Dua kemampuan:
 *
 * 1. RAHASIA PERANGKAT — `simpan`/`baca`/`hapus`/`ada`. Nilai (token sesi akun,
 *    kunci API Copilot, garam + turunan PIN, dan KUNCI basis data terenkripsi)
 *    disimpan TERENKRIPSI AES-256-GCM dengan kunci yang dibuat di Android
 *    Keystore (alias `plo_rahasia`) dan TIDAK BISA DIEKSPOR. Menyalin berkas
 *    basis data / berkas aplikasi ke perangkat lain TIDAK cukup untuk membaca
 *    isinya — termasuk untuk menebak PIN secara luring.
 *
 * 2. CADANGAN BERFRASA SANDI — `enkripsiSandi`/`dekripsiSandi`. Berkas cadangan
 *    JSON dienkripsi memakai kunci turunan frasa sandi pengguna
 *    (PBKDF2-HMAC-SHA256, 600.000 putaran, garam acak 16 byte) + AES-256-GCM.
 *    Amplopnya bisa dibawa ke HP lain (tidak terikat Keystore) karena kuncinya
 *    berasal dari frasa sandi yang diingat pengguna.
 *
 * Didaftarkan sebagai PAKET PLUGIN (bukan di MainActivity) supaya kanal ini ada
 * juga di mesin Flutter milik pekerja latar (Workmanager) — tanpa itu, pekerja
 * latar tidak bisa membaca kunci basis data dan pengingat akan berhenti.
 *
 * Aturan jujur: setiap kegagalan menjawab `false`/`null` — tidak pernah
 * mengembalikan nilai palsu atau menulis berkas tanpa perlindungan.
 */
class BrankasRahasiaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var saluran: MethodChannel? = null
    private var brankas: BrankasRahasia? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val mesin = BrankasRahasia(binding.applicationContext)
        brankas = mesin
        saluran = MethodChannel(binding.binaryMessenger, NAMA_KANAL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        saluran?.setMethodCallHandler(null)
        saluran = null
        brankas = null
    }

    override fun onMethodCall(panggilan: MethodCall, hasil: MethodChannel.Result) {
        val mesin = brankas
        if (mesin == null) {
            hasil.error("belum_siap", "Brankas belum siap.", null)
            return
        }
        when (panggilan.method) {
            "didukung" -> hasil.success(mesin.didukung())
            "simpan" -> hasil.success(
                mesin.simpan(
                    panggilan.argument<String>("nama"),
                    panggilan.argument<String>("nilai")
                )
            )
            "baca" -> hasil.success(mesin.baca(panggilan.argument<String>("nama")))
            "hapus" -> hasil.success(mesin.hapus(panggilan.argument<String>("nama")))
            "ada" -> hasil.success(mesin.ada(panggilan.argument<String>("nama")))
            "enkripsiSandi" -> hasil.success(
                mesin.enkripsiSandi(
                    panggilan.argument<String>("teks"),
                    panggilan.argument<String>("sandi")
                )
            )
            "dekripsiSandi" -> hasil.success(
                mesin.dekripsiSandi(
                    panggilan.argument<String>("amplop"),
                    panggilan.argument<String>("sandi")
                )
            )
            else -> hasil.notImplemented()
        }
    }

    companion object {
        /** Nama kanal — selaras `kanalBrankasRahasia` di sisi Dart. */
        const val NAMA_KANAL = "lifeos/rahasia"
    }
}

/** Penyimpanan rahasia berbasis Android Keystore (tanpa Activity). */
class BrankasRahasia(private val konteks: Context) {

    companion object {
        private const val ALIAS_KUNCI = "plo_rahasia"
        private const val PANJANG_IV = 12
        private const val PANJANG_TAG_BIT = 128
        private const val PANJANG_GARAM_SANDI = 16
        private const val PANJANG_KUNCI = 32

        /** Putaran PBKDF2 untuk cadangan berfrasa sandi (selaras OWASP 2023+). */
        const val PUTARAN_SANDI = 600_000

        /** Penanda format amplop cadangan terenkripsi. */
        const val MAGIC = "PLOENC2"

        private const val FOLDER = "rahasia"
    }

    private val acak = SecureRandom()

    // ── Rahasia perangkat ────────────────────────────────────────────────────

    fun didukung(): Boolean = try {
        kunci()
        true
    } catch (_: Exception) {
        false
    }

    fun simpan(nama: String?, nilai: String?): Boolean {
        if (nama.isNullOrBlank() || nilai == null) return false
        // Nama hanya boleh huruf, angka, titik, garis — mencegah keluar folder.
        if (!nama.matches(Regex("[A-Za-z0-9._-]{1,80}"))) return false
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, kunci())
            val iv = cipher.iv
            val terenkripsi = cipher.doFinal(nilai.toByteArray(Charsets.UTF_8))
            val tujuan = berkas(nama)
            tujuan.parentFile?.mkdirs()
            val sementara = File(tujuan.parentFile, "${tujuan.name}.tmp")
            sementara.outputStream().use { keluar ->
                keluar.write(iv.size)
                keluar.write(iv)
                keluar.write(terenkripsi)
            }
            // Ganti atomik supaya nilai lama tidak hilang bila penulisan gagal.
            if (tujuan.exists()) tujuan.delete()
            sementara.renameTo(tujuan)
        } catch (_: Exception) {
            false
        }
    }

    fun baca(nama: String?): String? {
        if (nama.isNullOrBlank()) return null
        val asal = berkas(nama)
        if (!asal.exists()) return null
        return try {
            asal.inputStream().use { masuk ->
                val panjang = masuk.read()
                if (panjang != PANJANG_IV) return null
                val iv = ByteArray(panjang)
                if (masuk.read(iv) != panjang) return null
                val sisa = masuk.readBytes()
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, kunci(), GCMParameterSpec(PANJANG_TAG_BIT, iv))
                String(cipher.doFinal(sisa), Charsets.UTF_8)
            }
        } catch (_: Exception) {
            null
        }
    }

    fun hapus(nama: String?): Boolean {
        if (nama.isNullOrBlank()) return false
        val berkas = berkas(nama)
        return if (!berkas.exists()) true else berkas.delete()
    }

    fun ada(nama: String?): Boolean =
        if (nama.isNullOrBlank()) false else berkas(nama).exists()

    // ── Cadangan berfrasa sandi ──────────────────────────────────────────────

    /**
     * Amplop terenkripsi (base64) dari [teks] dengan kunci turunan [sandi].
     *
     * Bentuk biner sebelum base64:
     * `PLOENC2`(7 byte) + garam(16) + iv(12) + ciphertext+tag(GCM).
     */
    fun enkripsiSandi(teks: String?, sandi: String?): String? {
        if (teks == null || sandi.isNullOrEmpty()) return null
        return try {
            val garam = ByteArray(PANJANG_GARAM_SANDI).also { acak.nextBytes(it) }
            val kunciAes = turunkanKunci(sandi, garam, PUTARAN_SANDI)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, kunciAes)
            val terenkripsi = cipher.doFinal(teks.toByteArray(Charsets.UTF_8))
            val keluaran = ByteArrayOutputStream()
            keluaran.write(MAGIC.toByteArray(Charsets.US_ASCII))
            keluaran.write(garam)
            keluaran.write(cipher.iv)
            keluaran.write(terenkripsi)
            Base64.getEncoder().encodeToString(keluaran.toByteArray())
        } catch (_: Exception) {
            null
        }
    }

    /** Kebalikan [enkripsiSandi]. `null` = sandi salah atau amplop rusak. */
    fun dekripsiSandi(amplop: String?, sandi: String?): String? {
        if (amplop.isNullOrEmpty() || sandi.isNullOrEmpty()) return null
        return try {
            val mentah = Base64.getDecoder().decode(amplop)
            val magic = MAGIC.toByteArray(Charsets.US_ASCII)
            if (mentah.size < magic.size + PANJANG_GARAM_SANDI + PANJANG_IV + 16) return null
            if (!mentah.copyOfRange(0, magic.size).contentEquals(magic)) return null
            var posisi = magic.size
            val garam = mentah.copyOfRange(posisi, posisi + PANJANG_GARAM_SANDI)
            posisi += PANJANG_GARAM_SANDI
            val iv = mentah.copyOfRange(posisi, posisi + PANJANG_IV)
            posisi += PANJANG_IV
            val isi = mentah.copyOfRange(posisi, mentah.size)
            val kunciAes = turunkanKunci(sandi, garam, PUTARAN_SANDI)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, kunciAes, GCMParameterSpec(PANJANG_TAG_BIT, iv))
            String(cipher.doFinal(isi), Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    /** PBKDF2-HMAC-SHA256 → kunci AES-256. */
    private fun turunkanKunci(sandi: String, garam: ByteArray, putaran: Int): SecretKey {
        val pabrik = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val spesifikasi = PBEKeySpec(sandi.toCharArray(), garam, putaran, PANJANG_KUNCI * 8)
        return SecretKeySpec(pabrik.generateSecret(spesifikasi).encoded, "AES")
    }

    // ── Keystore & berkas ───────────────────────────────────────────────────

    private fun berkas(nama: String): File =
        File(File(konteks.filesDir, FOLDER), "$nama.enc")

    private fun keystore(): KeyStore =
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun kunci(): SecretKey {
        val ks = keystore()
        val ada = ks.getEntry(ALIAS_KUNCI, null) as? KeyStore.SecretKeyEntry
        if (ada != null) return ada.secretKey
        val pembuat = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        pembuat.init(
            KeyGenParameterSpec.Builder(
                ALIAS_KUNCI,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return pembuat.generateKey()
    }
}
