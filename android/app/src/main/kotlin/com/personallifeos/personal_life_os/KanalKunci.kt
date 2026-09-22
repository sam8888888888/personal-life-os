package com.personallifeos.personal_life_os

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * FR-26 — buka aplikasi dengan kunci perangkat (PIN / pola / sidik jari HP).
 *
 * Android yang memverifikasi pemilik perangkat lewat layar kunci sistem, jadi
 * aplikasi ini tidak pernah menyimpan sidik jari siapa pun. Bila HP tidak punya
 * kunci sama sekali, jawabannya `false` — bukan galat.
 */
class KanalKunci(private val aktivitas: Activity) : PluginRegistry.ActivityResultListener {

    companion object {
        private const val KODE_PERMINTAAN = 7311
    }

    private var tertunda: MethodChannel.Result? = null

    fun pasang(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, "lifeos/kunci").setMethodCallHandler { panggilan, hasil ->
            when (panggilan.method) {
                "tersedia" -> hasil.success(punyaKunci())
                "buka" -> buka(hasil)
                else -> hasil.notImplemented()
            }
        }
    }

    private fun punyaKunci(): Boolean {
        val kunci = aktivitas.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            kunci.isDeviceSecure
        } else {
            @Suppress("DEPRECATION")
            kunci.isKeyguardSecure
        }
    }

    private fun buka(hasil: MethodChannel.Result) {
        if (!punyaKunci()) {
            hasil.success(false)
            return
        }
        if (tertunda != null) {
            hasil.error("sedang_berjalan", "Permintaan kunci lain sedang berjalan", null)
            return
        }
        val kunci = aktivitas.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val niat = kunci.createConfirmDeviceCredentialIntent(
            "Buka Personal Life OS",
            "Masukkan PIN, pola, atau sidik jari HP Anda"
        )
        if (niat == null) {
            hasil.success(false)
            return
        }
        tertunda = hasil
        aktivitas.startActivityForResult(niat, KODE_PERMINTAAN)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != KODE_PERMINTAAN) return false
        val hasil = tertunda ?: return true
        tertunda = null
        hasil.success(resultCode == Activity.RESULT_OK)
        return true
    }
}
