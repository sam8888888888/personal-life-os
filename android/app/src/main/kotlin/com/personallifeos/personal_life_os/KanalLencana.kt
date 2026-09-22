package com.personallifeos.personal_life_os

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * FR-22 — lencana angka di ikon peluncur.
 *
 * Android tidak punya satu API resmi untuk lencana: tiap peluncur punya siaran
 * (broadcast) sendiri. Karena itu aplikasi mengirim siaran ke merek-merek yang
 * dikenal, lalu berkata apa adanya bila tidak ada yang menerima. Sebagian
 * peluncur modern menampilkan titik lencana otomatis dari notifikasi aplikasi.
 */
class KanalLencana(private val konteks: Context) {

    fun pasang(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, "lifeos/lencana").setMethodCallHandler { panggilan, hasil ->
            if (panggilan.method != "pasang") {
                hasil.notImplemented()
                return@setMethodCallHandler
            }
            val jumlah = panggilan.argument<Int>("jumlah") ?: 0
            hasil.success(terapkan(jumlah))
        }
    }

    /** Kembalikan `true` bila ada siaran lencana yang benar-benar dikirim. */
    private fun terapkan(jumlah: Int): Boolean {
        val paket = konteks.packageName
        val kelas = ComponentName(konteks, MainActivity::class.java)
        var dikirim = false

        fun kirim(intent: Intent) {
            try {
                konteks.sendBroadcast(intent)
                dikirim = true
            } catch (_: Exception) {
                // peluncur tidak ada — bukan alasan menggagalkan
            }
        }

        // Samsung
        kirim(Intent("android.intent.action.BADGE_COUNT_UPDATE").apply {
            putExtra("badge_count", jumlah)
            putExtra("badge_count_package_name", paket)
            putExtra("badge_count_class_name", kelas.className)
        })
        // Sony
        kirim(Intent("com.sonyericsson.home.action.UPDATE_BADGE").apply {
            putExtra("com.sonyericsson.home.intent.extra.badge.PACKAGE_NAME", paket)
            putExtra("com.sonyericsson.home.intent.extra.badge.ACTIVITY_NAME", kelas.className)
            putExtra("com.sonyericsson.home.intent.extra.badge.MESSAGE", jumlah.toString())
            putExtra("com.sonyericsson.home.intent.extra.badge.SHOW_MESSAGE", jumlah > 0)
        })
        // HTC
        kirim(Intent("com.htc.launcher.action.UPDATE_SHORTCUT").apply {
            putExtra("packagename", paket)
            putExtra("count", jumlah)
        })
        kirim(Intent("com.htc.launcher.action.SET_NOTIFICATION").apply {
            putExtra("com.htc.launcher.extra.COMPONENT", kelas.flattenToShortString())
            putExtra("com.htc.launcher.extra.COUNT", jumlah)
        })
        // LG
        kirim(Intent("com.lge.launcher2.action.BADGE_COUNT_UPDATE").apply {
            putExtra("badge_count", jumlah)
            putExtra("badge_count_package_name", paket)
            putExtra("badge_count_class_name", kelas.className)
        })
        // Nova / Lawnchair
        kirim(Intent("com.teslacoilsw.launcher.ACTION_BADGE_COUNT_UPDATE").apply {
            putExtra("count", jumlah)
            putExtra("packageName", paket)
            putExtra("className", kelas.className)
        })
        // ADW
        kirim(Intent("org.adw.launcher.counter.SEND").apply {
            putExtra("PNAME", paket)
            putExtra("COUNT", jumlah)
            putExtra("CLASS", kelas.className)
        })
        // Apex / lain-lain yang memakai nama komponen pendek
        kirim(Intent("com.anddoes.launcher.COUNTER_CHANGED").apply {
            putExtra("package", paket)
            putExtra("class", kelas.className)
            putExtra("count", jumlah)
        })

        return dikirim
    }
}
